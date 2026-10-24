import urllib.request
import json

url = "http://localhost:8000/rest/v1/rpc/admin_get_database_analytics"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3OTIyMjU5NDksImV4cCI6MTk0OTkwNTk0OX0.4PjCu5EVlcxq1lrdXfSERS_hwX-xp5iRQxheyytMiiU"
req = urllib.request.Request(
    url,
    data=b"{}",
    headers={
        "apikey": token,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    print("STATUS:", resp.status)
    print("Storage:", data.get("storage"))
    print("CPU:", data.get("cpu"))
    print("RAM:", data.get("ram"))
    print("Realtime:", data.get("realtime"))
    print("Schools count:", len(data.get("school_comparison", [])))
    print("Platform:", data.get("platform_distribution"))
    print("Peak hours count:", len(data.get("peak_hours", [])))
    print("Health:", data.get("executive_health"))
