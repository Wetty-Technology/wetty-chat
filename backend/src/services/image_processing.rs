use image::AnimationDecoder;

const MAX_STICKER_DIMENSION: u32 = 512;

pub struct ProcessedMedia {
    pub data: Vec<u8>,
    pub content_type: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

/// Process an image sticker: resize so the largest dimension is 512px and convert to webp.
/// Animated GIF/WebP stickers are stored as-is to preserve animation.
/// For video/webm, only extracts dimensions (no re-encoding).
pub fn process_sticker(
    content_type: &str,
    data: &[u8],
) -> Result<ProcessedMedia, ProcessStickerError> {
    if content_type.starts_with("image/") {
        if is_animated_image(content_type, data) {
            tracing::debug!("animated sticker detected, storing original");
            return Ok(ProcessedMedia {
                data: data.to_vec(),
                content_type: content_type.to_string(),
                width: None,
                height: None,
            });
        }
        return process_image_sticker(data).ok_or(ProcessStickerError::InvalidImage);
    } else if content_type == "video/webm" {
        let dims = extract_webm_dimensions(data);
        return Ok(ProcessedMedia {
            data: data.to_vec(),
            content_type: content_type.to_string(),
            width: dims.map(|(w, _)| w),
            height: dims.map(|(_, h)| h),
        });
    }
    Err(ProcessStickerError::InvalidImage)
}

#[derive(Debug)]
pub enum ProcessStickerError {
    InvalidImage,
}

fn is_animated_image(content_type: &str, data: &[u8]) -> bool {
    match content_type {
        "image/gif" => is_animated_gif(data),
        "image/webp" => is_animated_webp(data),
        _ => false,
    }
}

fn is_animated_gif(data: &[u8]) -> bool {
    let Ok(decoder) = image::codecs::gif::GifDecoder::new(std::io::Cursor::new(data)) else {
        return false;
    };
    let mut frames = decoder.into_frames();
    // If there's a first frame and a second frame, it's animated
    frames.next().is_some() && frames.next().is_some()
}

fn is_animated_webp(data: &[u8]) -> bool {
    let Ok(decoder) = image::codecs::webp::WebPDecoder::new(std::io::Cursor::new(data)) else {
        return false;
    };
    decoder.has_animation()
}

fn process_image_sticker(data: &[u8]) -> Option<ProcessedMedia> {
    let reader = image::ImageReader::new(std::io::Cursor::new(data))
        .with_guessed_format()
        .ok()?;
    let img = reader.decode().ok()?;

    let img = if img.width() > MAX_STICKER_DIMENSION || img.height() > MAX_STICKER_DIMENSION {
        img.resize(
            MAX_STICKER_DIMENSION,
            MAX_STICKER_DIMENSION,
            image::imageops::FilterType::Lanczos3,
        )
    } else {
        img
    };

    let (w, h) = (img.width() as i32, img.height() as i32);

    let mut buf = std::io::Cursor::new(Vec::new());
    img.write_to(&mut buf, image::ImageFormat::WebP).ok()?;

    Some(ProcessedMedia {
        data: buf.into_inner(),
        content_type: "image/webp".to_string(),
        width: Some(w),
        height: Some(h),
    })
}

pub fn extract_webm_dimensions(data: &[u8]) -> Option<(i32, i32)> {
    let cursor = std::io::Cursor::new(data);
    let mkv = matroska::Matroska::open(cursor).ok()?;
    let track = mkv.video_tracks().next()?;
    if let matroska::Settings::Video(video) = &track.settings {
        Some((video.pixel_width as i32, video.pixel_height as i32))
    } else {
        None
    }
}
