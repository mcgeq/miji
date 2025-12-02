// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           tray_manager.rs
// Description:    系统托盘管理器（仅桌面平台）
// Create   Date:  2025-11-11
// -----------------------------------------------------------------------------

#[cfg(desktop)]
use tauri::{
    AppHandle, Emitter, Manager,
    menu::{MenuBuilder, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    WindowEvent,
};

/// 创建系统托盘
#[cfg(desktop)]
pub fn create_system_tray(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    // 创建菜单项
    let settings_item = MenuItem::with_id(app, "settings", "设置", true, None::<&str>)?;
    let quit_item = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;

    // 创建菜单
    let menu = MenuBuilder::new(app)
        .item(&settings_item)
        .separator()
        .item(&quit_item)
        .build()?;

    // 创建托盘图标
    let _tray = TrayIconBuilder::new()
        .icon(app.default_window_icon().unwrap().clone())
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(move |app, event| {
            handle_menu_event(app, event.id.as_ref());
        })
        .on_tray_icon_event(|tray, event| {
            handle_tray_icon_event(tray, event);
        })
        .build(app)?;

    log::info!("系统托盘创建成功");
    Ok(())
}

/// 处理托盘菜单事件
#[cfg(desktop)]
fn handle_menu_event(app: &AppHandle, event_id: &str) {
    match event_id {
        "settings" => {
            // 导航到设置页面
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                let _ = window.eval("window.location.hash = '#/settings'");
            }
        }
        "quit" => {
            app.exit(0);
        }
        _ => {}
    }
}

/// 处理托盘图标事件
#[cfg(desktop)]
fn handle_tray_icon_event(tray: &tauri::tray::TrayIcon, event: TrayIconEvent) {
    if let TrayIconEvent::Click {
        button: MouseButton::Left,
        button_state: MouseButtonState::Up,
        ..
    } = event
    {
        // 左键点击托盘图标显示/隐藏窗口
        let app = tray.app_handle();
        if let Some(window) = app.get_webview_window("main") {
            if window.is_visible().unwrap_or(false) {
                let _ = window.hide();
            } else {
                let _ = window.unminimize();
                let _ = window.show();
                let _ = window.set_focus();
            }
        }
    }
}

/// 设置窗口关闭处理器
#[cfg(desktop)]
pub fn setup_window_close_handler(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    if let Some(window) = app.get_webview_window("main") {
        let app_handle = app.clone();
        window.on_window_event(move |event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                log::info!("检测到窗口关闭请求");
                
                // 阻止默认关闭行为
                api.prevent_close();

                // 检查当前页面是否为登录或注册页面
                let app_handle_clone = app_handle.clone();
                tauri::async_runtime::spawn(async move {
                    if let Some(window) = app_handle_clone.get_webview_window("main") {
                        // 发送检查事件到前端
                        if let Err(e) = window.emit("check-auth-page", ()) {
                            log::error!("发送检查认证页面事件失败: {}", e);
                        } else {
                            log::info!("已发送检查认证页面事件");
                        }
                    }
                });
            }
        });
    } else {
        log::warn!("未找到主窗口，无法设置关闭处理器");
    }
    
    Ok(())
}
