use diesel::connection::{Instrumentation, InstrumentationEvent};

pub(crate) struct TracingInstrumentation;

impl Instrumentation for TracingInstrumentation {
    fn on_connection_event(&mut self, event: InstrumentationEvent<'_>) {
        match event {
            InstrumentationEvent::StartQuery { query, .. } => {
                tracing::trace!(sql = %query, "db query");
            }
            InstrumentationEvent::FinishQuery {
                query,
                error: Some(err),
                ..
            } => {
                tracing::error!(sql = %query, error = %err, "db query failed");
            }
            _ => {}
        }
    }
}

/// Call once at startup. Only installs instrumentation in debug builds.
pub(crate) fn install() {
    {
        diesel::connection::set_default_instrumentation(|| Some(Box::new(TracingInstrumentation)))
            .expect("failed to set diesel instrumentation");
    }
}
