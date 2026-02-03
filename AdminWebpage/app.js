const loginForm = document.querySelector("[data-login-form]");

if (loginForm) {
  loginForm.addEventListener("submit", (event) => {
    event.preventDefault();

    const username = loginForm.querySelector("[name='username']").value.trim();
    const password = loginForm.querySelector("[name='password']").value.trim();

    if (!username || !password) {
      alert("Please enter both a username and password.");
      return;
    }

    localStorage.setItem("ridematch_user", username);
    window.location.href = "home.html";
  });
}

const homePage = document.querySelector("[data-page='home']");

if (homePage) {
  const storedUser = localStorage.getItem("ridematch_user");
  if (!storedUser) {
    window.location.href = "login.html";
  }
}
