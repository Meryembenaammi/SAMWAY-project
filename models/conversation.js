const mongoose = require('mongoose');

// Schéma pour les messages individuels
const messageSchema = new mongoose.Schema({
  role: {
    type: String,
    enum: ['user', 'bot', 'bot_typing'],
    required: true
  },
  text: {
    type: String,
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now
  },
  data: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  reasoning: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  bookingResult: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  },
  itinerary: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  }
});

// Schéma principal pour les conversations
const conversationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.Mixed,
    required: true,
    index: true // Index pour les recherches rapides
  },
  title: {
    type: String,
    required: true
  },
  messages: [messageSchema],
  detectedCity: {
    type: String,
    default: '',
    index: true // Index pour les recherches par ville
  },
  departureLocation: {
    type: String,
    default: ''
  },
  arrivalLocation: {
    type: String,
    default: ''
  },
  departureDate: {
    type: String,
    default: ''
  },
  arrivalDate: {
    type: String,
    default: ''
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true // Index pour le tri par date de création
  },
  updatedAt: {
    type: Date,
    default: Date.now,
    index: true // Index pour le tri par date de mise à jour
  },
  status: {
    type: String,
    enum: ['active', 'archived', 'deleted'],
    default: 'active',
    index: true // Index pour filtrer par statut
  }
});

// Middleware pour mettre à jour updatedAt avant chaque sauvegarde
conversationSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Middleware pour valider l'userId avant la sauvegarde
conversationSchema.pre('save', function(next) {
  // Vérifier si l'userId est un ObjectId valide ou un timestamp
  if (typeof this.userId === 'string') {
    if (!/^\d{13}$/.test(this.userId) && !mongoose.Types.ObjectId.isValid(this.userId)) {
      return next(new Error('Invalid userId format'));
    }
  }
  next();
});

// Index composés pour des requêtes plus rapides
conversationSchema.index({ userId: 1, updatedAt: -1 });
conversationSchema.index({ userId: 1, status: 1 });
conversationSchema.index({ detectedCity: 1, status: 1 });

// Méthode statique pour trouver les conversations d'un utilisateur
conversationSchema.statics.findByUserId = async function(userId) {
  try {
    // Essayer de convertir en ObjectId si c'est une chaîne valide
    let query = { userId };
    if (typeof userId === 'string') {
      if (mongoose.Types.ObjectId.isValid(userId)) {
        query = { userId: new mongoose.Types.ObjectId(userId) };
      } else if (!/^\d{13}$/.test(userId)) {
        throw new Error('Invalid userId format');
      }
    }
    
    return await this.find(query)
      .sort({ updatedAt: -1 })
      .select('title messages createdAt updatedAt detectedCity userId status')
      .limit(10);
  } catch (error) {
    console.error('Error in findByUserId:', error);
    throw error;
  }
};

module.exports = mongoose.model('Conversation', conversationSchema); 