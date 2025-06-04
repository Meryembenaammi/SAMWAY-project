const nodemailer = require('nodemailer');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD
  },
  tls: {
    rejectUnauthorized: false
  }
});

// Fonction pour générer le PDF
const generatePDF = async (tripSummary, departure = '', destination = '', userName = '') => {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 50,
        info: {
          Title: 'Confirmation de réservation SAMWay',
          Author: 'SAMWay Travel',
        }
      });

      const pdfPath = path.join(__dirname, '../temp', `reservation-${Date.now()}.pdf`);
      
      // Créer le dossier temp s'il n'existe pas
      if (!fs.existsSync(path.join(__dirname, '../temp'))) {
        fs.mkdirSync(path.join(__dirname, '../temp'));
      }

      // Créer le stream d'écriture
      const stream = fs.createWriteStream(pdfPath);
      doc.pipe(stream);

      // --- Ajout de l'image d'avion en haut ---
      const planeImgPath = 'C:/Users/Han/Desktop/S8 4 A/PROJET INTERGRE/backend/flutter_application/assets/plane.jpg';
      if (fs.existsSync(planeImgPath)) {
        doc.image(planeImgPath, doc.page.width / 2 - 50, 30, { width: 100 });
        doc.moveDown(2.5);
      }

      // En-tête avec logo et titre
      doc
        .fillColor('#4A90E2')
        .fontSize(40)
        .text('SAMWay', { align: 'center' })
        .moveDown(0.5);

      doc
        .fillColor('#2C3E50')
        .fontSize(24)
        .text('Confirmation de réservation', { align: 'center' })
        .moveDown(1);

      // --- Billet d'avion stylisé (boarding pass) ---
      if (departure || destination) {
        const yStart = doc.y;
        // Fond bleu clair du boarding pass avec ombre
        doc.save();
        doc.roundedRect(70, yStart, 400, 100, 12)
          .fillAndStroke('#e3f0fa', '#4A90E2')
          .stroke();
        doc.restore();

        // Bandeau bleu foncé en haut avec dégradé
        doc.save();
        doc.rect(70, yStart, 400, 30).fill('#4A90E2');
        doc.restore();

        // Texte "BOARDING PASS" avec effet
        doc
          .fillColor('#fff')
          .fontSize(16)
          .font('Helvetica-Bold')
          .text('BOARDING PASS', 80, yStart + 8);

        // Ligne décorative sous le bandeau
        doc
          .strokeColor('#fff')
          .lineWidth(1)
          .moveTo(70, yStart + 30)
          .lineTo(470, yStart + 30)
          .stroke();

        // Villes avec flèche stylisée
        doc
          .fillColor('#222')
          .fontSize(24)
          .font('Helvetica-Bold')
          .text(
            `${departure || '---'}   ---->  ${destination || '---'}`,
            110, yStart + 45, { width: 320, align: 'center' }
          );

        // Ligne décorative sous les villes
        doc
          .strokeColor('#4A90E2')
          .lineWidth(1)
          .moveTo(70, yStart + 70)
          .lineTo(470, yStart + 70)
          .stroke();

        // Infos passager avec style amélioré
        doc
          .fontSize(11)
          .font('Helvetica-Bold')
          .fillColor('#4A90E2')
          .text('PASSENGER', 80, yStart + 80)
          .text('DATE', 200, yStart + 80)
          .text('SEAT', 320, yStart + 80);

        doc
          .fontSize(12)
          .font('Helvetica')
          .fillColor('#222')
          .text(userName || 'John Doe', 80, yStart + 90)
          .text(new Date().toISOString().slice(0, 10), 200, yStart + 90)
          .text('4B', 320, yStart + 90);

        doc.moveDown(7);
      }

      // Ligne décorative avec style
      doc
        .strokeColor('#4A90E2')
        .lineWidth(3)
        .moveTo(50, doc.y)
        .lineTo(545, doc.y)
        .stroke()
        .moveDown(1.5);

      // Section Détails du voyage élégante avec image alignée à droite
      const hotelImgPath = 'C:/Users/Han/Desktop/S8 4 A/PROJET INTERGRE/backend/flutter_application/assets/hotel.jpg';
      const detailsY = doc.y;
      
      // Fond gris clair pour la section
      doc.save();
      doc.rect(50, detailsY - 10, 495, 80)
        .fill('#f8f9fa');
      doc.restore();

      // Texte et image alignés sur la même ligne
      doc
        .fillColor('#2C3E50')
        .fontSize(22)
        .font('Helvetica-Bold')
        .text('Détails du voyage', 70, detailsY + 15, { underline: true, continued: true });
      if (fs.existsSync(hotelImgPath)) {
        doc.image(hotelImgPath, 320, detailsY, { width: 70, height: 70 });
      }
      doc.moveDown(3);

      // Convertir le HTML en texte simple pour le PDF avec style amélioré
      const plainText = tripSummary
        .replace(/<[^>]*>/g, '')
        .replace(/&nbsp;/g, ' ')
        .trim();

      // Style amélioré pour le contenu
      doc
        .fillColor('#34495E')
        .fontSize(13)
        .font('Helvetica')
        .text(plainText, {
          align: 'left',
          lineGap: 8,
          paragraphGap: 10
        })
        .moveDown(2);

      // Section Footer avec style amélioré
      doc
        .fillColor('#4A90E2')
        .fontSize(16)
        .font('Helvetica-Bold')
        .text('Merci d\'avoir choisi SAMWay pour votre voyage !', {
          align: 'center'
        })
        .moveDown(1);

      // Informations de contact avec style
      doc
        .fillColor('#7F8C8D')
        .fontSize(12)
        .font('Helvetica')
        .text('Pour toute question, contactez-nous à support@samway.com', {
          align: 'center'
        })
        .moveDown(1);

      // Filigrane avec style amélioré
      doc
        .fillColor('#E0E0E0')
        .fontSize(80)
        .font('Helvetica-Bold')
        .text('SAMWay', {
          align: 'center',
          valign: 'center',
          opacity: 0.05
        });

      // Finaliser le PDF
      doc.end();

      // Attendre que le stream soit fermé
      stream.on('finish', () => {
        resolve(pdfPath);
      });

      stream.on('error', (error) => {
        reject(error);
      });
    } catch (error) {
      reject(error);
    }
  });
};

const sendConfirmationEmail = async (userEmail, tripSummary, departure = '', destination = '', userName = '') => {
  try {
    // Générer le PDF avec les villes et le nom
    const pdfPath = await generatePDF(tripSummary, departure, destination, userName);

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: userEmail,
      subject: 'Confirmation de votre réservation SAMWay',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #4A90E2; text-align: center;">Confirmation de votre réservation</h1>
          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h2 style="color: #2C3E50;">Détails du voyage</h2>
            ${tripSummary}
          </div>
          <p style="color: #4A90E2; text-align: center; font-weight: bold;">Merci d'avoir choisi SAMWay pour votre voyage !</p>
          <p style="color: #7F8C8D; text-align: center; font-size: 14px;">Vous trouverez les détails de votre réservation en pièce jointe.</p>
        </div>
      `,
      attachments: [{
        filename: 'reservation.pdf',
        path: pdfPath
      }]
    };

    await transporter.sendMail(mailOptions);
    
    // Supprimer le fichier PDF temporaire après l'envoi
    fs.unlinkSync(pdfPath);
    
    return true;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email:', error);
    throw error;
  }
};

module.exports = { sendConfirmationEmail }; 