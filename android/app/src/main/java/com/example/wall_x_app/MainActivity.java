package com.example.wall_x_app;

import android.app.WallpaperManager;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.FileOutputStream;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.wallx.app/wallpaper";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("setWallpaper")) {
                    String filePath = call.argument("path");
                    Integer screenType = call.argument("screenType");
                    setWallpaper(filePath, screenType, result);
                } else {
                    result.notImplemented();
                }
            });
    }

    private void setWallpaper(String filePath, Integer screenType, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                File srcFile = new File(filePath);
                if (!srcFile.exists()) {
                    new Handler(Looper.getMainLooper()).post(() ->
                        result.error("FILE_NOT_FOUND", "File not found", null));
                    return;
                }

                // App cache mein copy karo
                File cacheDir = new File(getCacheDir(), "wallpapers");
                if (!cacheDir.exists()) cacheDir.mkdirs();
                File cacheFile = new File(cacheDir, "wallpaper_to_set.jpg");
                copyFile(srcFile, cacheFile);

                // Content URI banao FileProvider se
                Uri contentUri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".fileprovider",
                    cacheFile
                );

                // Pehle try: direct WallpaperManager
                boolean success = false;
                try {
                    InputStream inputStream = getContentResolver().openInputStream(contentUri);
                    Bitmap bitmap = BitmapFactory.decodeStream(inputStream);
                    if (inputStream != null) inputStream.close();

                    if (bitmap != null) {
                        WallpaperManager wm = WallpaperManager.getInstance(getApplicationContext());
                        int flags = WallpaperManager.FLAG_SYSTEM;
                        if (screenType == 2) flags = WallpaperManager.FLAG_LOCK;
                        else if (screenType == 0) flags = WallpaperManager.FLAG_SYSTEM | WallpaperManager.FLAG_LOCK;

                        wm.setBitmap(bitmap, null, true, flags);
                        bitmap.recycle();
                        success = true;
                    }
                } catch (Exception e) {
                    success = false;
                }

                // Agar direct set fail ho toh Intent se open karo
                if (!success) {
                    Intent intent = new Intent(Intent.ACTION_SET_WALLPAPER);
                    intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    intent.setDataAndType(contentUri, "image/*");

                    // chooser add karo
                    Intent chooser = Intent.createChooser(intent, "Wallpaper Set Karein");
                    chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(chooser);
                    success = true; // Intent open ho gaya
                }

                // Cleanup
                if (srcFile.exists()) srcFile.delete();

                new Handler(Looper.getMainLooper()).post(() -> {
                    if (success) {
                        result.success(true);
                    } else {
                        result.error("FAILED", "Wallpaper set nahi ho paya", null);
                    }
                });
            } catch (Exception e) {
                new Handler(Looper.getMainLooper()).post(() ->
                    result.error("ERROR", e.getMessage(), null));
            }
        }).start();
    }

    private void copyFile(File src, File dst) throws Exception {
        InputStream in = new FileInputStream(src);
        FileOutputStream out = new FileOutputStream(dst);
        byte[] buf = new byte[4096];
        int len;
        while ((len = in.read(buf)) > 0) {
            out.write(buf, 0, len);
        }
        in.close();
        out.close();
    }
}
