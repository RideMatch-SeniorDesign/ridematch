from __future__ import annotations

import os
from flask import Flask, redirect, render_template, request, session, url_for

app = Flask(__name__, static_folder="static", template_folder="templates")
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")


def _is_logged_in() -> bool:
    return bool(session.get("logged_in"))


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if not username or not password:
            error = "Please enter both a username and password."
        else:
            session["logged_in"] = True
            session["username"] = username
            return redirect(url_for("home"))

    return render_template("login.html", error=error)


@app.route("/home")
def home():
    if not _is_logged_in():
        return redirect(url_for("login"))

    return render_template("home.html", username=session.get("username"))


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("login"))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=True)
