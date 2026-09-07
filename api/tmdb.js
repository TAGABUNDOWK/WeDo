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

  const apiKey = process.env.TMDB_API;
  if (!apiKey) {
    return res.status(500).json({ error: "TMDB API key not configured" });
  }

  try {
    const { path, ...params } = req.query;
    if (!path) {
      return res.status(400).json({ error: "path query parameter is required" });
    }

    const tmdbParams = new URLSearchParams({ api_key: apiKey, ...params });
    const url = `https://api.themoviedb.org/3/${path}?${tmdbParams}`;

    const response = await fetch(url);
    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    return res.status(200).json(data);
  } catch (error) {
    console.error("tmdb proxy error:", error);
    return res.status(500).json({ error: "Failed to fetch from TMDB" });
  }
};
