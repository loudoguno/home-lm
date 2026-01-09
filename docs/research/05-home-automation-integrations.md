# Home Automation Integrations

How to connect Home LM with weather stations, Home Assistant, and other data sources.

---

## Weather Station Integration

### Ambient Weather API

If you have an Ambient Weather station, you can pull historical and real-time data.

**Setup:**
1. Get API keys from your [Ambient Weather Dashboard](https://ambientweather.net/dashboard)
2. Generate both Application Key and API Key

**API Usage:**

```typescript
// Get device data
const response = await fetch(
  `https://api.ambientweather.net/v1/devices?` +
  `applicationKey=${APP_KEY}&apiKey=${API_KEY}`
);
const devices = await response.json();

// Get historical data
const history = await fetch(
  `https://api.ambientweather.net/v1/devices/${macAddress}?` +
  `applicationKey=${APP_KEY}&apiKey=${API_KEY}&limit=288`  // 24 hours of 5-min data
);
```

**Available Data:**
- Temperature (indoor/outdoor)
- Humidity
- Barometric pressure
- Wind speed/direction
- Rain rate and totals
- UV index
- Solar radiation

**Python Library:** [aioambient](https://pypi.org/project/aioambient/)

```python
from aioambient import API

api = API(application_key, api_key)
devices = await api.get_devices()
```

### Ecowitt Local API

For Ecowitt gateways (GW1000, GW1100), you can query locally without cloud:

```bash
# Undocumented but works
curl http://192.168.1.xx/get_livedata_info
```

Or use [gw1000-http](https://github.com/bmrzycki/gw1000-http) for a REST API wrapper.

---

## Home Assistant Integration

### Approach 1: Webhook Receiver

Home LM receives events from Home Assistant automations.

**Home Assistant automation:**

```yaml
automation:
  - alias: "Log flooding to Home LM"
    trigger:
      - platform: state
        entity_id: binary_sensor.basement_water_sensor
        to: "on"
    action:
      - service: rest_command.log_to_homelm
        data:
          event_type: "flooding"
          area: "AREA/Basement"
          message: "Water detected in basement"

rest_command:
  log_to_homelm:
    url: "http://homelm.local/api/events"
    method: POST
    content_type: "application/json"
    payload: >
      {
        "type": "{{ event_type }}",
        "area": "{{ area }}",
        "message": "{{ message }}",
        "timestamp": "{{ now().isoformat() }}"
      }
```

**Home LM endpoint:**

```typescript
// src/routes/api/events/+server.ts
export async function POST({ request }) {
  const event = await request.json();

  // Create daily note entry
  const entry = `
${formatTime(event.timestamp)} - **${event.type}**
[[${event.area}]]: ${event.message}
(Auto-logged from Home Assistant)
`;

  await appendToDailyNote(entry);

  return json({ success: true });
}
```

### Approach 2: Pull Data from Home Assistant

Query Home Assistant's REST API or WebSocket for historical data.

```typescript
// Get entity history
const response = await fetch(
  `http://homeassistant.local:8123/api/history/period/${startDate}?` +
  `filter_entity_id=sensor.outdoor_temperature`,
  {
    headers: { Authorization: `Bearer ${HA_TOKEN}` }
  }
);
```

### Approach 3: Long-Term Statistics

For efficient historical queries, use Home Assistant's statistics API:

```typescript
// Get hourly statistics
const stats = await fetch(
  `http://homeassistant.local:8123/api/history/statistics`,
  {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${HA_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      statistic_ids: ['sensor.rain_daily'],
      start_time: '2024-01-01T00:00:00Z',
      end_time: '2024-12-31T23:59:59Z',
      period: 'day'
    })
  }
);
```

---

## Time-Series Correlation

### The Goal

Answer questions like: "When was the last time it rained 5+ inches and did the pantry flood?"

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA SOURCES                              │
├─────────────────────────────────────────────────────────────┤
│  Weather Station → InfluxDB (time series)                   │
│  Home Assistant → InfluxDB (sensor data)                    │
│  Home LM → PostgreSQL (events, notes)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    QUERY LAYER                               │
├─────────────────────────────────────────────────────────────┤
│  LLM receives: weather data + event logs + knowledge base   │
│  Correlates: "5 inches rain" + "pantry flooding" entries    │
└─────────────────────────────────────────────────────────────┘
```

### InfluxDB Setup

```yaml
# docker-compose.yml addition
services:
  influxdb:
    image: influxdb:2
    volumes:
      - influxdb_data:/var/lib/influxdb2
    ports:
      - "8086:8086"
```

### Home Assistant → InfluxDB

```yaml
# Home Assistant configuration.yaml
influxdb:
  api_version: 2
  host: influxdb
  port: 8086
  token: your-influxdb-token
  organization: home
  bucket: homeassistant
  include:
    entities:
      - sensor.outdoor_temperature
      - sensor.rain_daily
      - binary_sensor.basement_water_sensor
```

### Correlation Query

```typescript
async function correlateWeatherAndEvents(query: string) {
  // 1. Find flooding events in Home LM
  const floodingEvents = await db.query(`
    SELECT journal_date, content
    FROM blocks
    WHERE content ILIKE '%flood%' OR content ILIKE '%water%'
    ORDER BY journal_date DESC
  `);

  // 2. For each event, get weather data from InfluxDB
  const correlatedData = await Promise.all(
    floodingEvents.map(async (event) => {
      const weather = await influx.query(`
        from(bucket: "weather")
        |> range(start: ${event.journal_date}T00:00:00Z, stop: ${event.journal_date}T23:59:59Z)
        |> filter(fn: (r) => r["_measurement"] == "rain")
        |> sum()
      `);
      return { event, rainfall: weather };
    })
  );

  // 3. Feed to LLM for natural language response
  return generateResponse(correlatedData, query);
}
```

---

## Grafana Dashboards

### Visualizing Weather + Events

Create Grafana annotations for Home LM events:

```typescript
// When flooding is logged, create Grafana annotation
await fetch('http://grafana:3000/api/annotations', {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${GRAFANA_TOKEN}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    dashboardUID: 'weather-events',
    panelId: 1,
    time: Date.now(),
    tags: ['flooding', 'basement'],
    text: 'Water detected in basement'
  })
});
```

This lets you see weather graphs with incident markers overlaid.

---

## n8n Workflow Automation

### Example: Auto-Log Weather Events

```json
{
  "nodes": [
    {
      "name": "Weather Trigger",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "weather-alert"
      }
    },
    {
      "name": "Format Entry",
      "type": "n8n-nodes-base.set",
      "parameters": {
        "values": {
          "entry": "Heavy rain alert: {{ $json.rainfall }}mm in last hour"
        }
      }
    },
    {
      "name": "Log to Home LM",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://homelm.local/api/events",
        "method": "POST",
        "body": {
          "message": "{{ $json.entry }}",
          "type": "weather"
        }
      }
    }
  ]
}
```

---

## Implementation Plan

### Phase 1: Manual Weather Logging

Just note weather events in daily notes manually:
```
Heavy rain today (~3 inches). No flooding observed.
```

### Phase 2: Weather API Integration

1. Set up Ambient Weather API credentials
2. Create scheduled job to pull daily summary
3. Auto-append weather summary to daily notes

### Phase 3: Home Assistant Webhooks

1. Configure Home Assistant to POST events to Home LM
2. Auto-log sensor alerts (water, smoke, temperature)
3. Include sensor data in daily notes

### Phase 4: Full Correlation

1. Set up InfluxDB for time-series storage
2. Create correlation queries
3. Build LLM pipeline that combines sources
4. Answer questions like "Show me flooding events with weather context"

---

## Example Queries

With full integration, Home LM could answer:

**"When was the last time it rained heavily and we had flooding?"**
```
Based on your logs and weather data:

The last significant flooding was on 2025-02-11 when 5.2 inches
of rain fell in 37 minutes. According to your entry from that day,
water pooled around the [[ASSET/Downstairs Water Tank]] but
[[PERSON/Username]] prevented damage using the [[ASSET/Fantiik Sump Pump]]
and [[ASSET/MIDEA Dehumidifier]].

Previous flooding events:
- 2024-08-15: 3.8 inches, minor pooling in pantry
- 2024-03-22: 4.1 inches, basement flooding
```

**"What's the relationship between heavy rain and pantry flooding?"**
```
Analyzing your 12 flooding incidents over the past 2 years:

- 10 of 12 occurred when rainfall exceeded 3 inches in 2 hours
- The pantry flooded 8 times, always when rain rate > 1.5 in/hr
- The sump pump was used 7 times successfully

Recommendation: Consider a backup sump pump for the pantry area.
```

---

## Sources

- Ambient Weather API: https://ambientweather.docs.apiary.io/
- Home Assistant InfluxDB: https://www.home-assistant.io/integrations/influxdb/
- Home Assistant Statistics: https://data.home-assistant.io/docs/statistics/
- Grafana Annotations: https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/annotate-visualizations/
- n8n Home Assistant: https://n8n.io/integrations/home-assistant/
