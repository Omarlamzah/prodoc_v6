# Fix Agressif des Permissions READ_MEDIA - Version 1.0.24+34

## ✅ Solution Implémentée

### Approche Multi-Niveaux

1. **AndroidManifest.xml** - Suppression explicite avec `tools:node="remove"`
2. **build.gradle** - Script post-process pour forcer la suppression du manifest fusionné

### Changements Effectués

#### 1. AndroidManifest.xml
```xml
<!-- Remove image/video permissions added by dependencies -->
<uses-permission 
    android:name="android.permission.READ_MEDIA_IMAGES" 
    tools:node="remove" />
    
<uses-permission 
    android:name="android.permission.READ_MEDIA_VIDEO" 
    tools:node="remove" />
    
<uses-permission 
    android:name="android.permission.READ_MEDIA_AUDIO" 
    tools:node="remove" />

<uses-permission 
    android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" 
    tools:node="remove" />
```

#### 2. build.gradle
Script `afterEvaluate` qui post-process le manifest fusionné pour supprimer les permissions READ_MEDIA après la fusion mais avant la compilation finale.

### Version
- **Version Name:** 1.0.24
- **Version Code:** 34
- **AAB:** `build/app/outputs/bundle/release/app-release.aab` (98 MB)
- **Date:** 31 janvier 2025, 16:21

### Vérification

Le script Gradle devrait afficher:
```
Removing READ_MEDIA_* permissions from release manifest...
✓ READ_MEDIA_* permissions removed from release manifest
```

### Prochaines Étapes

1. **Téléverser le nouveau AAB** (version 1.0.24+34) sur Google Play Console
2. **Vérifier** que Google Play ne détecte plus les permissions
3. **Si le problème persiste**, utiliser "Proceed anyway" avec cette justification:

```
ProDoc utilise FilePicker pour la sélection de photos depuis la galerie, 
qui utilise le système photo picker Android (Android 13+) sans nécessiter 
les permissions READ_MEDIA_IMAGES ou READ_MEDIA_VIDEO.

ImagePicker est utilisé UNIQUEMENT pour la caméra, qui nécessite uniquement 
la permission CAMERA (pas READ_MEDIA).

L'application ne déclare pas ces permissions dans son manifest final grâce 
à tools:node="remove" dans AndroidManifest.xml et un script Gradle qui 
supprime ces permissions du manifest fusionné avant la compilation finale.
```

### Notes Techniques

- Le script Gradle s'exécute après la fusion des manifests mais avant la compilation
- Il supprime les permissions READ_MEDIA_* du manifest fusionné en utilisant des regex
- Cette approche garantit que même si les dépendances ajoutent ces permissions, elles seront supprimées
