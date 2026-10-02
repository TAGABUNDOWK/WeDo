module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const apiKey = process.env.GOOGLE_WEATHER_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "GOOGLE_WEATHER_API_KEY not configured" });
  }

  try {
    const { path, ...params } = req.query;
    if (!path) {
      return res.status(400).json({ error: "path query parameter is required" });
    }

    if (typeof path !== "string" || !/^[a-zA-Z0-9/:._-]+$/.test(path) || path.includes("..")) {
      return res.status(400).json({ error: "invalid path query parameter" });
    }

    const forwarded = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (typeof value === "string") forwarded.set(key, value);
    }
    forwarded.set("key", apiKey);

    const url = `https://weather.googleapis.com/v1/${path}?${forwarded}`;
    const response = await fetch(url);
    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    return res.status(200).json(data);
  } catch (error) {
    console.error("weather proxy error:", error);
    return res.status(500).json({ error: "Failed to fetch from Google Weather" });
  }
};
