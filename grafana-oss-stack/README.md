# Grafana OSS Stack

Self-hosted observability stack with OpenTelemetry collection via Grafana Alloy.

## Components

| Service | Purpose | Port |
|---------|---------|------|
| Grafana | Visualization UI | 3000 |
| Prometheus | Metrics storage | 9090 |
| Loki | Log aggregation | 3100 |
| Tempo | Distributed tracing | 3200 |
| Alloy | OTEL collector | 4317 (gRPC), 4318 (HTTP) |

## Quick Start

### Prerequisites

1. **Configure DNS entries** on your Pi-hole (192.168.1.3) using the v6 API:
   ```bash
   # Add all Grafana stack DNS entries at once
   ~/workspace/_scripts/pihole-add-grafana-dns.sh 192.168.1.YOUR_SERVER_IP

   # Or add individual entries
   ~/workspace/_scripts/pihole-add-dns.sh grafana.thinkcenter.dev 192.168.1.YOUR_SERVER_IP
   ~/workspace/_scripts/pihole-add-dns.sh alloy-otlp.thinkcenter.dev 192.168.1.YOUR_SERVER_IP
   ```

2. **Verify DNS** is working:
   ```bash
   nslookup grafana.thinkcenter.dev 192.168.1.3
   ```

### Deployment

1. Copy environment file:
   ```bash
   cp .env.example .env
   # Edit .env with secure passwords
   ```

2. Start the stack:
   ```bash
   docker-compose up -d
   ```

3. Access Grafana:
   - URL: `https://grafana.thinkcenter.dev`
   - Default credentials: `admin/admin` (change immediately)

## OTEL Endpoints

Send your OpenTelemetry data to Alloy:

- **gRPC**: `http://alloy-otlp-grpc.thinkcenter.dev:4317`
- **HTTP**: `http://alloy-otlp.thinkcenter.dev:4318`

Or internally via Docker network:
- **gRPC**: `http://alloy:4317`
- **HTTP**: `http://alloy:4318`

## Example OTEL Configuration

### Python (OTLP)
```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

trace.set_tracer_provider(TracerProvider())
tracer_provider = trace.get_tracer_provider()

otlp_exporter = OTLPSpanExporter(
    endpoint="http://alloy:4317",
    insecure=True
)

span_processor = BatchSpanProcessor(otlp_exporter)
tracer_provider.add_span_processor(span_processor)
```

### Go (OTLP)
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
)

exporter, _ := otlptracegrpc.New(ctx,
    otlptracegrpc.WithEndpoint("alloy:4317"),
    otlptracegrpc.WithInsecure(),
)
```

### JavaScript/TypeScript (OTLP)
```typescript
import { trace } from '@opentelemetry/api';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';

const provider = new NodeTracerProvider();
const exporter = new OTLPTraceExporter({
    url: 'http://alloy:4317',
});
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();
```

## DNS Configuration

The Grafana stack requires DNS entries for the following services:

| Hostname | Purpose |
|----------|---------|
| `grafana.thinkcenter.dev` | Grafana UI |
| `prometheus.thinkcenter.dev` | Prometheus UI (optional) |
| `loki.thinkcenter.dev` | Loki API (internal) |
| `tempo.thinkcenter.dev` | Tempo API (internal) |
| `alloy-otlp.thinkcenter.dev` | OTEL HTTP endpoint |
| `alloy-otlp-grpc.thinkcenter.dev` | OTEL gRPC endpoint |

### Pi-hole Setup

Use the provided scripts that leverage Pi-hole v6's REST API:

**Add all Grafana stack entries at once:**
```bash
~/workspace/_scripts/pihole-add-grafana-dns.sh 192.168.1.YOUR_SERVER_IP
# Or with custom Pi-hole URL:
~/workspace/_scripts/pihole-add-grafana-dns.sh 192.168.1.YOUR_SERVER_IP http://192.168.1.3
# With password:
~/workspace/_scripts/pihole-add-grafana-dns.sh 192.168.1.YOUR_SERVER_IP http://192.168.1.3 YOUR_PASSWORD
```

**Add individual entries:**
```bash
~/workspace/_scripts/pihole-add-dns.sh grafana.thinkcenter.dev 192.168.1.YOUR_SERVER_IP
~/workspace/_scripts/pihole-add-dns.sh alloy-otlp.thinkcenter.dev 192.168.1.YOUR_SERVER_IP
```

**Verify DNS is working:**
```bash
nslookup grafana.thinkcenter.dev 192.168.1.3
ping grafana.thinkcenter.dev
```

#### API Endpoints Used

The scripts use Pi-hole v6's REST API:
- `POST /api/auth` - Authenticate and get session ID
- `GET /api/config/dns/hosts` - List existing DNS records
- `PUT /api/config/dns/hosts/{encoded_record}` - Add DNS record (format: "IP DOMAIN")
- `DELETE /api/config/dns/hosts/{encoded_record}` - Delete DNS record
- `DELETE /api/auth` - Logout/terminate session

## Storage Requirements

| Service | Estimated Size (30 days) |
|---------|--------------------------|
| Prometheus | ~10-20 GB |
| Loki | ~50-100 GB |
| Tempo | ~30-50 GB |
| Grafana | ~1 GB |

## Maintenance

### View logs
```bash
docker-compose logs -f grafana
docker-compose logs -f alloy
```

### Backup data
```bash
tar -czf grafana-backup-$(date +%Y%m%d).tar.gz ./data/grafana
```

### Update images
```bash
docker-compose pull
docker-compose up -d
```

## References

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
