// index.js
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Connexion à MongoDB
mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log("✅ MongoDB TravelPlanner connecté"))
.catch((err) => console.error("❌ Erreur MongoDB:", err));

// Importation des routes
const chatRoutes = require("./routes/chat");
const hotelRoutes = require("./routes/hotels");
const citiesRoutes = require("./routes/cities");
const authRoutes = require("./routes/auth");

// Utilisation des routes
app.use("/api/chat", chatRoutes);
app.use("/api/hotels", hotelRoutes);
app.use("/api/available-cities", citiesRoutes);
app.use("/api", authRoutes);

// Route GET de base
app.get("/", (req, res) => {
  res.send("🚀 API SAMWay est en ligne !");
});

// Route POST de test à la racine (utile pour curl)
app.post("/", (req, res) => {
  const { message } = req.body;
  console.log("Message reçu à la racine :", message);
  res.json({ reply: `Tu as dit : ${message}` });
});

// Démarrage du serveur
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Serveur lancé sur http://localhost:${PORT}`);
});
