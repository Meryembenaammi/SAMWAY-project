const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs'); // ou 'bcrypt'
const jwt = require('jsonwebtoken'); // Optionnel, pour les tokens d'auth

// TODO: Importer tes contrôleurs ou ta logique d'authentification si tu utilises un pattern MVC/séparé
// Pour l'instant, la logique est directement dans les routes pour la démo.

// --- Schéma et Modèle Utilisateur --- (Tu pourrais mettre ça dans un fichier séparé comme models/User.js)
const UserSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true, // Assure que l'email est unique
  },
  password: {
    type: String,
    required: true,
  },
  date: {
    type: Date,
    default: Date.now,
  },
});

// Middleware pour hacher le mot de passe avant de sauvegarder
UserSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

const User = mongoose.model('User', UserSchema);

// -------------------------------------

// Route POST pour l'inscription
router.post('/register', async (req, res) => {
  const { name, email, password } = req.body;

  try {
    // Vérifier si l'utilisateur existe déjà
    let user = await User.findOne({ email });

    if (user) {
      return res.status(400).json({ success: false, message: 'Cet email est déjà utilisé.' });
    }

    // Créer une nouvelle instance d'utilisateur
    user = new User({
      name,
      email,
      password, // Le middleware pre('save') va hacher le mot de passe
    });

    // Sauvegarder l'utilisateur dans la base de données
    await user.save();

    // Renvoyer une réponse de succès (sans le mot de passe haché)
    res.status(201).json({ success: true, message: 'Inscription réussie !' });

  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: 'Erreur serveur lors de l\'inscription.' });
  }
});

// Route POST pour la connexion
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    // Vérifier si l'utilisateur existe
    let user = await User.findOne({ email });

    if (!user) {
      // Important: ne dis pas si c'est l'email ou le mot de passe qui est faux pour des raisons de sécurité
      return res.status(400).json({ success: false, message: 'Identifiants invalides.' });
    }

    // Comparer les mots de passe (le mot de passe fourni avec le mot de passe haché)
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
       // Important: ne dis pas si c'est l'email ou le mot de passe qui est faux pour des raisons de sécurité
      return res.status(400).json({ success: false, message: 'Identifiants invalides.' });
    }

    // --- Générer un Token JWT (Optionnel mais recommandé) ---
    // Ce token servira à authentifier les requêtes futures
    const payload = {
      user: {
        id: user.id,
      },
    };

    jwt.sign(
      payload,
      process.env.JWT_SECRET, // Utilise une clé secrète stockée dans tes variables d'environnement (.env)
      { expiresIn: '1h' }, // Le token expire après 1 heure (adapte la durée)
      (err, token) => {
        if (err) throw err;
        // Renvoyer la réponse de succès avec le token
        res.json({ success: true, token });
      }
    );
    // ----------------------------------------------------

    // Si tu ne veux pas de token, tu peux simplement renvoyer un succès:
    // res.json({ success: true, message: 'Connexion réussie !' });

  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: 'Erreur serveur lors de la connexion.' });
  }
});

module.exports = router; 