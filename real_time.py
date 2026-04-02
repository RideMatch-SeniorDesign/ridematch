from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret")

socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode="eventlet"
)

INTERNAL_API_KEY = os.getenv("INTERNAL_API_KEY", "change-this-key")

# session tracking
sid_to_identity = {}
identity_to_sids = {}


VALID_USER_TYPES = {"driver", "rider", "admin"}
VALID_TARGET_TYPES = {"driver", "rider", "admin", "broadcast", "room"}


def make_identity_key(user_type, user_id):
    return f"{user_type}:{user_id}"


def make_user_room(user_type, user_id):
    return f"{user_type}_{user_id}"

def is_authorized(req):
    return req.headers.get("X-Internal-Key") == INTERNAL_API_KEY

def add_connection(user_type, user_id, sid):
    identity_key = make_identity_key(user_type, user_id)

    sid_to_identity[sid] = {
        "user_type": user_type,
        "user_id": user_id
    }

    if identity_key not in identity_to_sids:
        identity_to_sids[identity_key] = set()

    identity_to_sids[identity_key].add(sid)

def remove_connection(sid):
    identity = sid_to_identity.pop(sid, None)
    if not identity:
        return None

    identity_key = make_identity_key(identity["user_type"], identity["user_id"])

    if identity_key in identity_to_sids:
        identity_to_sids[identity_key].discard(sid)
        if not identity_to_sids[identity_key]:
            del identity_to_sids[identity_key]

    return identity

def get_active_connection_count(user_type, user_id):
    identity_key = make_identity_key(user_type, user_id)
    return len(identity_to_sids.get(identity_key, set()))

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "connected_sockets": len(sid_to_identity),
        "connected_users": len(identity_to_sids)
    }), 200

@app.route("/publish-event", methods=["POST"])
def publish_event():
    """
    Send to one user:
    {
      "source": "admin_server",
      "target_type": "driver",
      "target_id": 42,
      "event": "admin_alert",
      "payload": {
        "title": "Document Expiring",
        "message": "Upload a new insurance card"
      }
    }

    Send to all users of a type:
    {
      "source": "admin_server",
      "target_type": "room",
      "room": "drivers",
      "event": "system_notice",
      "payload": {
        "message": "Maintenance at 11 PM"
      }
    }

    Broadcast to every connected socket:
    {
      "source": "admin_server",
      "target_type": "broadcast",
      "event": "system_notice",
      "payload": {
        "message": "Platform update tonight"
      }
    }
    """
    if not is_authorized(request):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}

    source = str(data.get("source", "unknown_server")).strip()
    target_type = str(data.get("target_type", "")).strip().lower()
    event_name = str(data.get("event", "")).strip()
    payload = data.get("payload", {})

    if target_type not in VALID_TARGET_TYPES:
        return jsonify({
            "error": "target_type must be one of: driver, rider, admin, room, broadcast"
        }), 400

    if not event_name:
        return jsonify({"error": "event is required"}), 400

    # attach source info into outgoing payload
    if isinstance(payload, dict):
        payload = {
            "source": source,
            **payload
        }
    else:
        payload = {
            "source": source,
            "data": payload
        }

    # one user target
    if target_type in {"driver", "rider", "admin"}:
        target_id = str(data.get("target_id", "")).strip()
        if not target_id:
            return jsonify({"error": "target_id is required"}), 400

        room_name = make_user_room(target_type, target_id)
        socketio.emit(event_name, payload, room=room_name)

        active_connections = get_active_connection_count(target_type, target_id)

        return jsonify({
            "success": True,
            "source": source,
            "target_type": target_type,
            "target_id": target_id,
            "event": event_name,
            "delivered_live": active_connections > 0,
            "active_connections": active_connections
        }), 200

    # room target
    if target_type == "room":
        room_name = str(data.get("room", "")).strip()
        if not room_name:
            return jsonify({"error": "room is required when target_type='room'"}), 400

        socketio.emit(event_name, payload, room=room_name)

        return jsonify({
            "success": True,
            "source": source,
            "target_type": "room",
            "room": room_name,
            "event": event_name
        }), 200

    # full broadcast
    if target_type == "broadcast":
        socketio.emit(event_name, payload)

        return jsonify({
            "success": True,
            "source": source,
            "target_type": "broadcast",
            "event": event_name,
            "connected_sockets": len(sid_to_identity)
        }), 200

    return jsonify({"error": "Unhandled target_type"}), 400

@socketio.on("connect")
def handle_connect():
    print(f"[CONNECT] sid={request.sid}")
    emit("connected", {"message": "Connected to realtime hub"})


@socketio.on("register_user")
def handle_register_user(data):
    """
    Client sends:
    {
      "user_type": "driver",
      "user_id": 42
    }

    user_type can be: driver, rider, admin
    """
    payload = data or {}

    user_type = str(payload.get("user_type", "")).strip().lower()
    user_id = str(payload.get("user_id", "")).strip()

    if user_type not in VALID_USER_TYPES:
        emit("register_error", {"error": "user_type must be driver, rider, or admin"})
        return

    if not user_id:
        emit("register_error", {"error": "user_id is required"})
        return

    add_connection(user_type, user_id, request.sid)

    # personal room
    join_room(make_user_room(user_type, user_id))

    # group room by type
    if user_type == "driver":
        join_room("drivers")
    elif user_type == "rider":
        join_room("riders")
    elif user_type == "admin":
        join_room("admins")

    print(f"[REGISTER] {user_type}:{user_id} sid={request.sid}")

    emit("register_success", {
        "message": "User registered successfully",
        "user_type": user_type,
        "user_id": user_id
    })


@socketio.on("unregister_user")
def handle_unregister_user():
    identity = sid_to_identity.get(request.sid)

    if not identity:
        emit("unregister_error", {"error": "This socket is not registered"})
        return

    user_type = identity["user_type"]
    user_id = identity["user_id"]

    leave_room(make_user_room(user_type, user_id))

    if user_type == "driver":
        leave_room("drivers")
    elif user_type == "rider":
        leave_room("riders")
    elif user_type == "admin":
        leave_room("admins")

    remove_connection(request.sid)

    print(f"[UNREGISTER] {user_type}:{user_id} sid={request.sid}")

    emit("unregister_success", {
        "message": "User unregistered successfully",
        "user_type": user_type,
        "user_id": user_id
    })


@socketio.on("disconnect")
def handle_disconnect():
    identity = remove_connection(request.sid)

    if identity:
        print(
            f"[DISCONNECT] {identity['user_type']}:{identity['user_id']} sid={request.sid}"
        )
    else:
        print(f"[DISCONNECT] unregistered sid={request.sid}")


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5001))
    socketio.run(app, host="0.0.0.0", port=port, debug=True)