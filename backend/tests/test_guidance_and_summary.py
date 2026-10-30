import io
from datetime import date
from PIL import Image


def test_settings_flow(client, auth_headers):
    # GET settings
    get_res = client.get("/api/v1/settings", headers=auth_headers)
    assert get_res.status_code == 200
    data = get_res.json()
    assert len(data["tracked_apps"]) >= 3  # YouTube, Instagram, Facebook seeded
    assert len(data["limits"]) >= 1

    # PUT settings
    put_res = client.put(
        "/api/v1/settings",
        json={
            "study_goals": "Crack Data Science Interview",
            "screenshot_consent": True,
            "has_video": True,
        },
        headers=auth_headers,
    )
    assert put_res.status_code == 200
    updated = put_res.json()
    assert updated["study_goals"] == "Crack Data Science Interview"
    assert updated["screenshot_consent"] is True
    assert updated["has_video"] is True


def test_usage_sync(client, auth_headers):
    today_str = date.today().isoformat()
    sync_res = client.post(
        "/api/v1/usage/sync",
        json={
            "records": [
                {
                    "app_name": "YouTube",
                    "date": today_str,
                    "total_minutes": 45,
                    "session_count": 3,
                },
                {
                    "app_name": "Instagram",
                    "date": today_str,
                    "total_minutes": 25,
                    "session_count": 2,
                },
            ]
        },
        headers=auth_headers,
    )
    assert sync_res.status_code == 200
    data = sync_res.json()
    assert data["success"] is True
    assert data["synced_records"] == 2


def test_guidance_and_reply_flow(client, auth_headers):
    # Create a small dummy in-memory image
    img = Image.new("RGB", (100, 100), color="blue")
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format="JPEG")
    img_byte_arr.seek(0)

    # 1. Call /guidance with multipart form data
    res = client.post(
        "/api/v1/guidance",
        data={
            "app_name": "YouTube",
            "session_minutes": "35",
            "daily_total_minutes": "75",
            "active_window_title": "Funny Memes Compilations - YouTube",
            "video_length_seconds": "3600",
            "video_watched_seconds": "1500",
        },
        files={"screenshot": ("screen.jpg", img_byte_arr, "image/jpeg")},
        headers=auth_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert "suggestion_id" in data
    assert "Bhai" in data["suggestion_text"] or len(data["suggestion_text"]) > 10
    suggestion_id = data["suggestion_id"]

    # 2. Record reply to the suggestion
    reply_res = client.post(
        f"/api/v1/suggestions/{suggestion_id}/reply",
        json={
            "user_reply": "Okay, I'll study",
            "action_taken_after": "closed_app",
            "follow_up_minutes": 40,
        },
        headers=auth_headers,
    )
    assert reply_res.status_code == 200
    reply_data = reply_res.json()
    assert reply_data["user_reply"] == "Okay, I'll study"
    assert reply_data["action_taken_after"] == "closed_app"


def test_daily_summary(client, auth_headers):
    # Sync some usage first
    today_str = date.today().isoformat()
    client.post(
        "/api/v1/usage/sync",
        json={
            "records": [
                {
                    "app_name": "YouTube",
                    "date": today_str,
                    "total_minutes": 50,
                    "session_count": 2,
                }
            ]
        },
        headers=auth_headers,
    )

    # Request guidance and reply
    g_res = client.post(
        "/api/v1/guidance",
        data={"app_name": "YouTube", "session_minutes": "20", "daily_total_minutes": "50"},
        headers=auth_headers,
    )
    s_id = g_res.json()["suggestion_id"]
    client.post(
        f"/api/v1/suggestions/{s_id}/reply",
        json={"user_reply": "followed", "action_taken_after": "closed_app"},
        headers=auth_headers,
    )

    # Fetch daily summary
    sum_res = client.get(f"/api/v1/summary/daily?date={today_str}", headers=auth_headers)
    assert sum_res.status_code == 200
    summary = sum_res.json()
    assert summary["total_screen_time_minutes"] == 50
    assert summary["suggestions_count"] >= 1
    assert summary["followed_count"] >= 1
    assert summary["compliance_percentage"] == 100.0
    assert len(summary["timeline"]) >= 1
    assert "Shabash" in summary["summary_message"] or "focus" in summary["summary_message"].lower()

