use futures::executor::{self};
use objc2::{MainThreadMarker, Message};
use objc2_ui_kit::UIView;
use raw_window_handle::{RawDisplayHandle, RawWindowHandle, UiKitDisplayHandle, UiKitWindowHandle};
use std::ptr::NonNull;
use thiserror::Error;
use wgpu::CurrentSurfaceTexture;

const SPEEDOMETER_SHADER: &str = include_str!("shaders/speedometer.wgsl");

pub type Speed = u64;

#[repr(u32)]
#[derive(Error, Debug)]
pub enum SpeedometerError {
    NonMainThread,
    CreateSurfaceError,
    RequestAdapterError,
    RequestDeviceError,
    CurrentSurfaceTextureError,
}

impl std::fmt::Display for SpeedometerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NonMainThread => write!(f, "called from non-main thread"),
            Self::CreateSurfaceError => write!(f, "failed to create WGPU surface"),
            Self::RequestAdapterError => write!(f, "failed to request WGPU adapter"),
            Self::RequestDeviceError => write!(f, "failed to request WGPU device"),
            Self::CurrentSurfaceTextureError => {
                write!(f, "failed to get current WGPU surface texture")
            }
        }
    }
}

struct Speedometer<'a> {
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface: wgpu::Surface<'a>,
    pipeline: wgpu::RenderPipeline,
    uniform_buffer: wgpu::Buffer,
    bind_group: wgpu::BindGroup,
}

impl<'a> Speedometer<'a> {
    fn new(ui_view: NonNull<UIView>) -> Result<Self, SpeedometerError> {
        let mut pool = executor::LocalPool::new();

        let view = unsafe { ui_view.as_ref() };
        let view = view.retain();

        // let _size = view.frame().size();
        // let _width = _size.width() as u32;
        // let _height = _size.height() as u32;

        let display_handle = RawDisplayHandle::UiKit(UiKitDisplayHandle::new());
        let window_handle = RawWindowHandle::UiKit(UiKitWindowHandle::new(ui_view.cast()));

        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::METAL,
            flags: Default::default(),
            backend_options: Default::default(),
            memory_budget_thresholds: Default::default(),
            display: None,
        });

        let surface = unsafe {
            instance.create_surface_unsafe(wgpu::SurfaceTargetUnsafe::RawHandle {
                raw_display_handle: Some(display_handle),
                raw_window_handle: window_handle,
            })
        }
        .map_err(|_| SpeedometerError::CreateSurfaceError)?;

        let adapter = pool
            .run_until(instance.request_adapter(&wgpu::RequestAdapterOptions::default()))
            .map_err(|_| SpeedometerError::RequestAdapterError)?;

        let descr = wgpu::DeviceDescriptor {
            label: None,
            required_features: wgpu::Features::empty(),
            required_limits: wgpu::Limits::default(),
            memory_hints: wgpu::MemoryHints::default(),
            trace: wgpu::Trace::Off,
            experimental_features: wgpu::ExperimentalFeatures::disabled(),
        };
        let (device, queue) = pool
            .run_until(adapter.request_device(&descr))
            .map_err(|_| SpeedometerError::RequestDeviceError)?;

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Speedometer Shader"),
            source: wgpu::ShaderSource::Wgsl(SPEEDOMETER_SHADER.into()),
        });

        let caps = surface.get_capabilities(&adapter);
        let surface_format = caps.formats[0];

        surface.configure(
            &device,
            &wgpu::SurfaceConfiguration {
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                format: surface_format,
                color_space: wgpu::SurfaceColorSpace::Auto,
                width: 1,
                height: 1,
                present_mode: wgpu::PresentMode::Mailbox,
                alpha_mode: wgpu::CompositeAlphaMode::Opaque,
                view_formats: vec![],
                desired_maximum_frame_latency: 2,
            },
        );

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Speedometer Bind Group Layout"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });

        let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Speedometer Uniform Buffer"),
            size: 16, // GaugeUniforms: value, aspect, time, pad (4 x f32)
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Speedometer Bind Group"),
            layout: &bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Speedometer Pipeline Layout"),
            bind_group_layouts: &[Some(&bind_group_layout)],
            immediate_size: 0,
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Speedometer Render Pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("gauge_vertex"),
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("gauge_fragment"),
                targets: &[Some(wgpu::ColorTargetState {
                    format: surface_format,
                    blend: None,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview_mask: None,
            cache: None,
        });

        drop(view);

        Ok(Self {
            device,
            queue,
            surface,
            pipeline,
            uniform_buffer,
            bind_group,
        })
    }

    /// Draws the speedometer gauge shader to the surface.
    fn draw(&mut self, value: Speed) -> Result<(), SpeedometerError> {
        let frame = self.surface.get_current_texture();
        // TODO: handle all other cases.
        let CurrentSurfaceTexture::Success(surface_texture) = frame else {
            return Err(SpeedometerError::CurrentSurfaceTextureError);
        };
        let view = surface_texture
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let normalized_value = (value as f32 / 100.0).clamp(0.0, 1.0);
        let aspect =
            surface_texture.texture.width() as f32 / surface_texture.texture.height() as f32;

        let uniforms: [f32; 4] = [normalized_value, aspect, 0.0, 0.0];

        self.queue
            .write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&uniforms));

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Speedometer Render Encoder"),
            });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Speedometer Render Pass"),
                multiview_mask: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
            });

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(0, &self.bind_group, &[]);
            render_pass.draw(0..3, 0..1);
        }

        self.queue.submit(Some(encoder.finish()));
        self.queue.present(surface_texture);

        Ok(())
    }
}

pub mod capi {

    use super::*;

    #[repr(C)]
    pub enum SpeedometerResult {
        Success,
        Error(SpeedometerError),
    }

    pub struct SpeedometerStatic {
        speedometer: Speedometer<'static>,
    }

    /// TODO: Consider returning real ObjC object with cbindgen:postfix=NS_RETURNS_RETAINED
    #[unsafe(no_mangle)]
    pub extern "C" fn speedometer_new(view: NonNull<UIView>) -> Option<NonNull<SpeedometerStatic>> {
        let _mtm = MainThreadMarker::new().expect("must be called on the main thread");

        let speedometer = Speedometer::new(view).expect("failed to create speedometer");

        let r: *mut SpeedometerStatic = Box::into_raw(Box::new(SpeedometerStatic { speedometer }));
        NonNull::new(r)
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn speedometer_free(speedometer: NonNull<SpeedometerStatic>) {
        let ptr = speedometer.as_ptr();
        let boxed = unsafe { Box::from_raw(ptr) };
        drop(boxed);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn speedometer_draw(
        mut speedometer: NonNull<SpeedometerStatic>,
        value: Speed,
    ) -> SpeedometerResult {
        let spd = unsafe { speedometer.as_mut() };
        if let Err(e) = spd.speedometer.draw(value) {
            return SpeedometerResult::Error(e);
        }

        SpeedometerResult::Success
    }
}
