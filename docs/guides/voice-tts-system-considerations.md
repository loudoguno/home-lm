# Voice & TTS System Considerations

A comprehensive guide for implementing voice input and text-to-speech output for Home LM.

---

## Vision

Enable household members to:
1. **Log entries hands-free**: "Hey Home, the dishwasher is making a weird noise again"
2. **Ask questions**: "When was the last time we serviced the HVAC?"
3. **Get contextual responses**: AI responds with information from the knowledge base

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    VOICE INPUT PIPELINE                      │
├─────────────────────────────────────────────────────────────┤
│  Microphone/Speaker → Wake Word → STT → Intent/Entity → AI  │
│   (Room devices)     (Local)    (Local)   (Local LLM)       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    VOICE OUTPUT PIPELINE                     │
├─────────────────────────────────────────────────────────────┤
│  AI Response → TTS Engine → Audio Output → Room Speakers    │
│               (Local)                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Hardware Options

### Option 1: Raspberry Pi Satellites (Recommended)

Deploy a Pi in each major room, connected to a central Home LM server.

| Component | Recommendation | Cost |
|-----------|---------------|------|
| **Board** | Raspberry Pi Zero 2 W | ~$15 |
| **Microphone** | ReSpeaker 2-Mic Pi HAT | ~$12 |
| **Speaker** | 3W speaker or line-out to existing | ~$5-10 |
| **Power** | USB power | included |

**Total per room**: ~$35-40

**Software**: [Wyoming Satellite](https://github.com/rhasspy/wyoming-satellite)

### Option 2: ESP32-based Devices

Lower cost, but more limited:

| Device | Features | Cost |
|--------|----------|------|
| M5Stack Atom Echo | Tiny, built-in mic + speaker | ~$13 |
| ESP32-S3-BOX | Screen, good audio | ~$50 |

**Software**: ESPHome with voice components

### Option 3: Repurposed Devices

- **Old Android tablets**: Run voice client app
- **USB speakerphone**: Connect to central Pi/server
- **Smart speaker hack**: Some can be modified (not recommended)

### Option 4: Dedicated Voice Terminal

A more substantial installation in a central location:

| Component | Recommendation | Cost |
|-----------|---------------|------|
| **Computer** | Intel NUC or Mac Mini | $300-600 |
| **Microphone** | Jabra Speak 510 (USB) | ~$100 |
| **Display** | Small touchscreen (optional) | ~$50-100 |

---

## Software Stack

### Speech-to-Text (STT) Options

| Engine | Hardware Needs | Speed | Accuracy | Local? |
|--------|---------------|-------|----------|--------|
| **Whisper (OpenAI)** | CPU OK, GPU better | 5-15s | Excellent | Yes |
| **faster-whisper** | CPU OK, GPU better | 2-5s | Excellent | Yes |
| **Whisper.cpp** | CPU optimized | 3-10s | Excellent | Yes |
| **Speech-to-Phrase** | Raspberry Pi 4 | <1s | Good (limited vocab) | Yes |
| **Vosk** | Low resources | <1s | Good | Yes |

**Recommendation**: `faster-whisper` for quality, `Vosk` for speed on limited hardware

### Wake Word Detection

| Engine | Notes |
|--------|-------|
| **OpenWakeWord** | Custom wake words, runs on Pi |
| **Porcupine** | Very accurate, limited free tier |
| **snowboy** | Older but still works |

**Recommendation**: OpenWakeWord (custom "Hey Home" wake word)

### Text-to-Speech (TTS) Options

| Engine | Quality | Speed | Local? |
|--------|---------|-------|--------|
| **Piper** | Good-Excellent | Fast | Yes |
| **Coqui TTS** | Excellent | Medium | Yes |
| **eSpeak** | Robotic | Very fast | Yes |
| **Mimic 3** | Good | Medium | Yes |

**Recommendation**: Piper (best quality/speed balance for local)

---

## Integration Architecture

### Home Assistant Integration (Simplest Path)

If you already run Home Assistant:

```
┌─────────────────────────────────────────────────────────────┐
│                    HOME ASSISTANT                            │
├─────────────────────────────────────────────────────────────┤
│  Wyoming Protocol → Assist → Custom Conversation Agent      │
│       (STT/TTS)              (Routes to Home LM API)        │
└─────────────────────────────────────────────────────────────┘
```

1. Install Wyoming add-on (Whisper + Piper)
2. Set up Wyoming satellites in rooms
3. Create custom conversation agent that queries Home LM
4. Home LM provides the knowledge base API

### Standalone Voice Server

Without Home Assistant:

```
┌─────────────────────────────────────────────────────────────┐
│                    HOME LM VOICE SERVER                      │
├─────────────────────────────────────────────────────────────┤
│  Wyoming Protocol   │  faster-whisper  │  Piper TTS         │
│  (satellite comm)   │  (STT)           │  (voice output)    │
├─────────────────────────────────────────────────────────────┤
│  OpenWakeWord       │  Ollama (LLM)    │  Home LM API       │
│  (wake detection)   │  (intent/response)│  (knowledge base) │
└─────────────────────────────────────────────────────────────┘
```

---

## Voice Pipeline Flow

### Input Flow (User speaks)

```
1. Wake word detected ("Hey Home")
2. Audio captured until silence
3. Audio sent to STT engine (faster-whisper)
4. Text extracted: "when did we last service the hot tub"
5. LLM processes intent:
   - Query type: HISTORICAL_LOOKUP
   - Entity: ASSET/Hot Tub
   - Attribute: maintenance, service
6. Home LM API queried with semantic search
7. Results formatted as natural response
8. Response sent to TTS
9. Audio played through room speaker
```

### Example Interactions

**Logging an event:**
```
User: "Hey Home, the toilet in the downstairs bathroom is running again"

System:
1. Detects entities: AREA/Downstairs Bathroom, ASSET/Toilet
2. Creates daily note entry:
   [[ASSET/Downstairs Bathroom Toilet]] is running again.
   (Detected from voice on [[2026-01-09]] at 3:42 PM)
3. Responds: "Got it. I've logged that the downstairs bathroom toilet
   is running. Would you like me to look up previous issues with it?"
```

**Asking a question:**
```
User: "Hey Home, how do you clean the Dyson vacuum?"

System:
1. Searches knowledge base for ASSET/Dyson Vacuum + cleaning
2. Finds relevant note from [[2024-08-15]]:
   "Cleaned the Dyson filter - remove, tap out dust, wash with
   cold water, let dry 24 hours before reinstalling"
3. Responds: "Based on your notes from August 2024, to clean the Dyson
   filter: remove it, tap out the dust, wash with cold water, and let
   it dry for 24 hours before putting it back."
```

---

## Hardware Setup Guide

### Raspberry Pi Satellite Setup

**Materials:**
- Raspberry Pi Zero 2 W
- ReSpeaker 2-Mic Pi HAT
- MicroSD card (8GB+)
- USB power supply
- 3.5mm speaker or powered speaker

**Installation:**

```bash
# Flash Raspberry Pi OS Lite to SD card

# Boot Pi and SSH in
ssh pi@raspberrypi.local

# Install Wyoming Satellite
git clone https://github.com/rhasspy/wyoming-satellite
cd wyoming-satellite
script/setup

# Configure for ReSpeaker HAT
# Edit config for your Home LM server address

# Start as service
sudo systemctl enable wyoming-satellite
sudo systemctl start wyoming-satellite
```

### Central Server Setup

**Requirements:**
- CPU: 4+ cores recommended
- RAM: 8GB minimum, 16GB recommended
- GPU: Optional but helpful for STT
- Storage: 20GB+ for models

**Software Installation:**

```bash
# Install faster-whisper
pip install faster-whisper

# Install Piper TTS
pip install piper-tts

# Download models
# Whisper: medium.en (best balance)
# Piper: en_US-amy-medium (natural voice)

# Install Wyoming server components
pip install wyoming
```

---

## Recommended Implementation Phases

### Phase 1: Basic Voice Input (Start Here)

1. Single room with Pi + microphone
2. faster-whisper for STT
3. Direct text append to daily notes
4. No TTS response (just confirmation beep)

**Cost**: ~$50-75
**Complexity**: Low

### Phase 2: Add Intelligence

1. LLM processing (Ollama with Llama 3)
2. Entity extraction from speech
3. Intent classification (log vs query)
4. Basic TTS responses with Piper

**Cost**: ~$100 additional (better Pi or server)
**Complexity**: Medium

### Phase 3: Multi-Room

1. Multiple Pi satellites
2. Room detection (which satellite heard)
3. Context-aware responses
4. Audio routing to correct room

**Cost**: ~$40-50 per additional room
**Complexity**: Medium-High

### Phase 4: Advanced Features

1. Custom wake word ("Hey Home")
2. Continuous conversation mode
3. Speaker identification
4. Integration with Home Assistant

**Cost**: Minimal (software)
**Complexity**: High

---

## Cost Summary

| Setup Level | Hardware Cost | Notes |
|-------------|--------------|-------|
| **Minimal** | ~$50 | Single Pi satellite, existing server |
| **Recommended** | ~$200-300 | 2-3 satellites + dedicated mini server |
| **Full House** | ~$400-600 | 5+ satellites + capable server |

---

## Alternative: Mobile App

Before investing in hardware, consider a mobile app approach:

1. PWA with voice input via Web Speech API
2. User speaks into phone
3. Processed on server
4. Response displayed (and optionally spoken)

**Pros**: No hardware cost, works immediately
**Cons**: Requires phone, not hands-free

---

## Key Decisions to Make

1. **Home Assistant integration?**
   - Yes: Use Wyoming protocol, leverage existing ecosystem
   - No: Build standalone voice server

2. **Local vs cloud STT?**
   - Local: Privacy, no internet needed, some accuracy tradeoff
   - Cloud: Better accuracy, requires internet, privacy concerns

3. **Wake word or push-to-talk?**
   - Wake word: True hands-free, requires always-on processing
   - Push-to-talk: Simpler, works with mobile app

4. **Single room vs whole house?**
   - Start with one room to validate
   - Expand once workflow is proven

---

## Resources

- [Wyoming Protocol](https://github.com/rhasspy/wyoming)
- [Wyoming Satellite](https://github.com/rhasspy/wyoming-satellite)
- [faster-whisper](https://github.com/guillaumekln/faster-whisper)
- [Piper TTS](https://github.com/rhasspy/piper)
- [OpenWakeWord](https://github.com/dscripka/openWakeWord)
- [Home Assistant Voice](https://www.home-assistant.io/voice_control/)
- [ReSpeaker Hardware](https://wiki.seeedstudio.com/ReSpeaker_2_Mics_Pi_HAT/)

---

## Next Steps

1. **Export your data** (see data-export-guide.md)
2. **Set up core Home LM** (web interface, data model)
3. **Validate the workflow** with keyboard input
4. **Then** add voice when the core system is working

Voice is a nice-to-have enhancement. The knowledge base itself is the core value.
