import io
import json
import logging
from datetime import datetime
from typing import Optional, Tuple
from PIL import Image
from app.core.config import settings

logger = logging.getLogger(__name__)


class AIGuidanceService:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.AI_MODEL_NAME
        self._genai_configured = False

    def _setup_gemini(self):
        if not self._genai_configured and self.api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._genai_configured = True
            except Exception as e:
                logger.warning(f"Failed to configure google.generativeai: {e}")

    async def analyze_screenshot_and_guide(
        self,
        image_bytes: Optional[bytes],
        app_name: str,
        session_minutes: int,
        daily_total_minutes: int,
        active_window_title: Optional[str] = None,
        study_goals: Optional[str] = None,
        video_length_seconds: Optional[int] = None,
        video_watched_seconds: Optional[int] = None,
    ) -> Tuple[bool, str, str, str, int]:
        """
        Analyzes the in-memory screenshot and context using Gemini Vision.
        Returns:
            (is_distracting: bool, activity_description: str, suggestion_text: str, suggested_action: str, follow_up_minutes: int)
        Guaranteed: Image bytes are strictly processed in RAM and never written to disk or database.
        """
        self._setup_gemini()

        current_hour = datetime.now().hour
        time_period = "raat" if current_hour >= 21 or current_hour <= 4 else ("shaam" if current_hour >= 17 else "din")

        context_prompt = f"""
You are FocusGuard, a supportive, witty, and deeply caring Indian study buddy / big brother.
Your job is to look at this user's screen or app context and give a friendly, crisp Hinglish reality-check.

Context Details:
- App Name: {app_name}
- Active Window/Title: {active_window_title or 'Distracting app'}
- Current Session Time: {session_minutes} minutes
- Total Spent Today: {daily_total_minutes} minutes
- Time of Day: {time_period} ({datetime.now().strftime('%I:%M %p')})
- User's Study Goal: {study_goals or 'Padhai aur goals complete karna'}
- Video Duration (if applicable): {f'{video_length_seconds // 60}m' if video_length_seconds else 'unknown'}
- Watched Time: {f'{video_watched_seconds // 60}m' if video_watched_seconds else 'unknown'}

Format your reply as valid JSON with these keys:
{{
  "is_distracting": true/false,
  "activity_description": "Short explanation of what user is doing",
  "suggestion_text": "Friendly Hinglish nudge. Example: 'Bhai, ye video bahut lamba hai (~1 hour) aur tu 20 min dekh chuka hai. Abhi apna kaam pehle kar le, 40 min baad dekh liyo.'",
  "suggested_action": "close_now" or "snooze" or "allow",
  "follow_up_minutes": 40 (number of minutes recommended to study before re-checking)
}}
"""

        # Attempt Gemini Vision call if configured and image is present
        if self.api_key and image_bytes:
            try:
                import google.generativeai as genai
                image = Image.open(io.BytesIO(image_bytes))
                model = genai.GenerativeModel(self.model_name)
                response = model.generate_content([context_prompt, image])
                
                response_text = response.text.strip()
                if response_text.startswith("```json"):
                    response_text = response_text[7:]
                if response_text.endswith("```"):
                    response_text = response_text[:-3]
                response_text = response_text.strip()

                data = json.loads(response_text)
                return (
                    bool(data.get("is_distracting", True)),
                    str(data.get("activity_description", f"Using {app_name}")),
                    str(data.get("suggestion_text", "")),
                    str(data.get("suggested_action", "close_now")),
                    int(data.get("follow_up_minutes", 40)),
                )
            except Exception as e:
                logger.error(f"Gemini Vision call failed, falling back to smart contextual generator: {e}")

        # Smart fallback generator (used if no API key or API call errors out)
        return self._generate_contextual_fallback(
            app_name=app_name,
            session_minutes=session_minutes,
            daily_total_minutes=daily_total_minutes,
            active_window_title=active_window_title,
            study_goals=study_goals,
            time_period=time_period,
            video_length_seconds=video_length_seconds,
            video_watched_seconds=video_watched_seconds,
        )

    def _generate_contextual_fallback(
        self,
        app_name: str,
        session_minutes: int,
        daily_total_minutes: int,
        active_window_title: Optional[str],
        study_goals: Optional[str],
        time_period: str,
        video_length_seconds: Optional[int],
        video_watched_seconds: Optional[int],
    ) -> Tuple[bool, str, str, str, int]:
        clean_app = app_name.capitalize()
        goal_text = f"'{study_goals}'" if study_goals else "apna target"
        
        if video_length_seconds and video_watched_seconds:
            v_len_m = max(1, video_length_seconds // 60)
            v_wat_m = max(1, video_watched_seconds // 60)
            remaining_m = max(5, v_len_m - v_wat_m)
            suggestion = (
                f"Bhai, ye video kaafi lamba hai (~{v_len_m} min) aur tu pehle hi {v_wat_m} min dekh chuka hai. "
                f"Abhi {goal_text} pehle nipta le, {min(40, remaining_m)} min baad dekh liyo!"
            )
            follow_up = min(40, remaining_m)
        elif "youtube" in app_name.lower():
            suggestion = (
                f"Bhai, YouTube pe scrolling chal rahi hai aur aaj already {daily_total_minutes} min ho gaye! "
                f"Abhi video pause kar aur {goal_text} pe focus kar. 40 min baad reward ke taur pe dekhna."
            )
            follow_up = 40
        elif "instagram" in app_name.lower():
            suggestion = (
                f"Bhai, Reels ka loop khatam nahi hoga! Aaj {daily_total_minutes} min Instagram chal chuka hai. "
                f"Phone rakh aur {goal_text} shuru kar, 30 min baad aana."
            )
            follow_up = 30
        elif "facebook" in app_name.lower():
            suggestion = (
                f"Bhai, Facebook feed scroll karne se exam ya target clear nahi hoga! "
                f"Pehle {goal_text} finish kar le, 45 min baad milte hain."
            )
            follow_up = 45
        else:
            suggestion = (
                f"Bhai, {clean_app} pe {session_minutes} min beet chuke hain. "
                f"Abhi break lo aur {goal_text} pe concentrate karo. 40 min baad wapas check karenge."
            )
            follow_up = 40

        activity = f"Distracted on {clean_app}"
        if active_window_title:
            activity += f" ({active_window_title[:40]})"

        return (True, activity, suggestion, "close_now", follow_up)


ai_guidance_service = AIGuidanceService()
