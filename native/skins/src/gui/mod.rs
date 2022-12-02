use eframe::{App, Frame, NativeOptions};
use egui::{Context, Vec2};
use crate::gui::skin_convert::SkinConvertData;

pub mod skin_convert;

fn scale(xy_scale: f32) -> Vec2 {
    Vec2::new(xy_scale, xy_scale)
}

pub struct SkinDebugApp {
    context: Option<Box<dyn SkinWindowContext>>
}

pub trait SkinWindowContext {
    fn update(&mut self, ctx: &Context);
}

pub fn start_gui() {
    let app = Box::new(
        SkinDebugApp {
            context: Some(Box::new(SkinConvertData::default()))
        }
    );

    let options = NativeOptions::default();
    eframe::run_native(
        "GlobalApi skin convert debugger",
        options,
        Box::new(|_| app)
    );
}

impl App for SkinDebugApp {
    fn update(&mut self, ctx: &Context, _frame: &mut Frame) {
        if let Some(context) = self.context.as_mut() {
            context.update(ctx);
        }
    }
}
