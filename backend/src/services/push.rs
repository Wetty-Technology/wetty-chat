use web_push::{HyperWebPushClient, VapidSignatureBuilder};

pub struct PushService {
    pub client: HyperWebPushClient,
    pub vapid_public_key: String,
    pub vapid_private_key: String,
    pub vapid_subject: String,
}

impl PushService {
    pub fn new() -> Self {
        let public_key = std::env::var("VAPID_PUBLIC_KEY")
            .expect("VAPID_PUBLIC_KEY environment variable must be set");
        let private_key = std::env::var("VAPID_PRIVATE_KEY")
            .expect("VAPID_PRIVATE_KEY environment variable must be set");
        let subject =
            std::env::var("VAPID_SUBJECT").expect("VAPID_SUBJECT environment variable must be set");

        // Validate the private key parses correctly.
        let _ = VapidSignatureBuilder::from_base64_no_sub(&private_key)
            .expect("Failed to create VapidSignatureBuilder from VAPID_PRIVATE_KEY");

        Self {
            client: HyperWebPushClient::new(),
            vapid_public_key: public_key,
            vapid_private_key: private_key,
            vapid_subject: subject,
        }
    }
}
