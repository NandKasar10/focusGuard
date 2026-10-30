def test_register_success(client):
    res = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Aman Sharma",
            "email": "aman@example.com",
            "password": "SecurePassword999",
            "study_goals": "Finish UPSC syllabus",
        },
    )
    assert res.status_code == 201
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_register_duplicate_email(client):
    payload = {
        "name": "Duplicate User",
        "email": "dup@example.com",
        "password": "Password123!",
    }
    res1 = client.post("/api/v1/auth/register", json=payload)
    assert res1.status_code == 201

    res2 = client.post("/api/v1/auth/register", json=payload)
    assert res2.status_code == 400
    assert "already exists" in res2.json()["detail"]


def test_login_success(client):
    email = "login_test@example.com"
    pwd = "MySecretPassword123"
    client.post(
        "/api/v1/auth/register",
        json={"name": "Login Tester", "email": email, "password": pwd},
    )

    res = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": pwd},
    )
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data


def test_login_invalid_credentials(client):
    res = client.post(
        "/api/v1/auth/login",
        json={"email": "nonexistent@example.com", "password": "wrongpassword"},
    )
    assert res.status_code == 401


def test_refresh_token(client):
    email = "refresh@example.com"
    pwd = "Password123!"
    reg_res = client.post(
        "/api/v1/auth/register",
        json={"name": "Refresh Tester", "email": email, "password": pwd},
    )
    tokens = reg_res.json()
    refresh_token = tokens["refresh_token"]

    ref_res = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert ref_res.status_code == 200
    new_tokens = ref_res.json()
    assert "access_token" in new_tokens
    assert "refresh_token" in new_tokens


def test_get_me(client, auth_headers):
    res = client.get("/api/v1/auth/me", headers=auth_headers)
    assert res.status_code == 200
    user_data = res.json()
    assert user_data["email"] == "test@focusguard.local"
    assert user_data["name"] == "Test User"

