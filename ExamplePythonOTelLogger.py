import logging
import os

from opentelemetry import trace
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (BatchSpanProcessor,
                                            ConsoleSpanExporter)

# Enable OpenTelemetry logging integration
print("Enabling OTel logging integration!")
LoggingInstrumentor().instrument(set_logging_format=True)

# Configure tracing
trace.set_tracer_provider(TracerProvider())
tracer_provider = trace.get_tracer_provider()
span_processor = processor = BatchSpanProcessor(ConsoleSpanExporter())
tracer_provider.add_span_processor(span_processor)

# Set up basic logging
logging.basicConfig(
    format=(
        "%(asctime)s %(levelname)s [%(name)s] [%(filename)s:%(lineno)d] "
        "[trace_id=%(otelTraceID)s span_id=%(otelSpanID)s sampled=%(otelTraceSampled)s] "
        "%(message)s"
    ),
    level=logging.INFO,
)

# Example logger usage
logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("example_span"):
    logger.info("This log includes OpenTelemetry trace context.")