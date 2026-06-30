# Release Notes - Version 1.0.20 (Build 30)

## 📦 Nouvelle Version pour Google Play Store

### Version
- **Version Name:** 1.0.20
- **Version Code:** 30
- **Date:** 31 janvier 2025

### 🎯 Changements Principaux

#### ✅ Correction des Permissions READ_MEDIA
- **Problème résolu:** Google Play détectait les permissions `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO`
- **Solution:** Remplacement de `ImageSource.gallery` par `FilePicker` pour la sélection de photos
- **Résultat:** Aucune permission READ_MEDIA déclarée, conforme aux politiques Google Play

#### 🔧 Modifications Techniques
- Utilisation de `FilePicker` au lieu de `ImagePicker` pour la galerie
- `ImagePicker` conservé uniquement pour la caméra (permission CAMERA uniquement)
- Simplification du manifest Android
- Suppression des scripts Gradle complexes

#### 📱 Fichiers Modifiés
- `lib/screens/attach_file_to_record_screen.dart`
- `lib/screens/medical_record_detail_screen.dart`
- `lib/screens/cabinet_info_screen.dart`
- `lib/widgets/patient_detail_tabs/patient_info_tab.dart`

### 📦 Fichier de Release
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **Taille:** 102.5 MB
- **Format:** Android App Bundle (AAB)

### ✅ Prêt pour Publication
Le fichier AAB est prêt à être téléversé sur Google Play Console.

### 📝 Notes
- Cette version utilise le photo picker système Android (conforme Google Play)
- Aucune déclaration spéciale nécessaire dans Google Play Console
- L'expérience utilisateur reste identique
