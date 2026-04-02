/// Clamp an optional user-supplied limit to `[1, max]`, defaulting to `max`.
pub fn validate_limit(limit: Option<i64>, max: i64) -> i64 {
    limit.map(|l| l.min(max)).unwrap_or(max).max(1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_to_max_when_none() {
        assert_eq!(validate_limit(None, 50), 50);
    }

    #[test]
    fn clamps_above_max() {
        assert_eq!(validate_limit(Some(200), 50), 50);
    }

    #[test]
    fn clamps_below_one() {
        assert_eq!(validate_limit(Some(0), 50), 1);
        assert_eq!(validate_limit(Some(-5), 50), 1);
    }

    #[test]
    fn passes_through_valid_value() {
        assert_eq!(validate_limit(Some(25), 50), 25);
    }
}
