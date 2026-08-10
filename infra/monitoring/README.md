# Production monitoring

The backend exposes `/api/v1/health` and `/api/v1/ready`. Use `/ready` for deployment health checks because it verifies PostgreSQL, Redis and storage configuration.

Prometheus configuration and alert rules in this directory are starter production configuration. Connect them to the selected Prometheus/Alertmanager or managed monitoring service and route critical alerts to the operations channel.
