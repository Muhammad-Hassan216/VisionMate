# VisionMate Refined System Architecture (Current + Planned)

```mermaid
flowchart LR
  %% Users
  VIU[Visually Impaired User]
  GUARD[Guardian]

  %% App container
  subgraph APP[VisionMate Flutter App]
    subgraph UI[User Interfaces]
      UMS[User Main Screen]
      GDash[Guardian Linked Dashboard]
      FaceReg[Face Registration / Manage Faces]
      Fav[Favorite Destinations Screen]
    end

    subgraph EDGE[On-Device AI + Safety]
      Cam[Camera Stream]
      Obj[ObjectDetector\nYOLOv8n int8 TFLite]
      FacePipe[OfflineRecognitionService\nMobileFaceNet + Similarity]
      LocalDB[SQLite Face DB\nEmbeddings + Recognition Logs]
      Fall[Fall Detection\nAccelerometer Rules]
      Voice[Voice Engine\nTTS + STT]
      Vol[Hardware Volume Handler]
      Nav[Route Guidance Logic\nStep Parsing + Turn Prompts]
    end

    subgraph SRV[App Services]
      Loc[LocationService]
      Tracker[UserLocationTracker]
      Sync[FirebaseToSQLiteSync]
    end
  end

  %% Cloud
  subgraph CLOUD[Cloud Services]
    Auth[Firebase Auth]
    FS[(Firestore\nusers + registered_faces + sosAlert)]
    Maps[Google Directions/Geocoding API]
  end

  %% Hardware
  subgraph HW[Phone Hardware]
    GPS[GPS]
    Mic[Microphone]
    Spk[Speaker]
    Acc[Accelerometer]
    VolBtn[Volume Buttons]
  end

  %% User interactions
  VIU --> UMS
  GUARD --> GDash
  UMS --> FaceReg
  UMS --> Fav

  %% Perception pipeline
  Cam --> Obj
  Cam --> FacePipe
  Obj --> UMS
  FacePipe --> UMS
  FacePipe <--> LocalDB
  Sync --> LocalDB
  FS --> Sync

  %% Navigation pipeline
  UMS --> Nav
  Nav --> Maps
  Maps --> Nav
  GPS --> Loc
  Loc --> UMS

  %% Voice + volume trigger
  VolBtn --> Vol
  Vol --> Voice
  Mic --> Voice
  Voice --> Spk
  Voice --> Nav

  %% Current implemented trigger
  Vol -. double-press .-> Voice

  %% Planned feature (as discussed)
  Vol -. triple-press (planned) .-> Fav

  %% Safety pipeline
  Acc --> Fall
  Fall --> UMS
  Fall --> Voice
  Fall --> Tracker
  Tracker --> FS
  GPS --> Tracker

  %% Guardian + auth/data
  UMS <--> Auth
  GDash <--> Auth
  UMS --> FS
  GDash <--> FS

  %% Critical battery SOS (service-level)
  Tracker --> FS
```

## Notes

- Implemented now:
  - Object detection: `assets/models/yolov8n_int8.tflite` via `ObjectDetector`.
  - Offline face recognition: `OfflineRecognitionService` + `MobileFaceNetService` + local SQLite embeddings.
  - Fall safety workflow: free-fall + impact logic, countdown prompt, SOS to Firestore.
  - Guardian sync: location/battery updates and SOS records via `UserLocationTracker`.
  - Voice pipeline: TTS/STT with volume-button trigger flow.

- Planned/remaining:
  - Triple-press volume shortcut to Favorite Destinations (shown as dashed planned link).

- Suggested figure caption for report:
  - "Refined VisionMate architecture showing on-device perception, guardian cloud synchronization, emergency safety loop, and planned triple-press favorite-destination shortcut."