package com.newsblur.activity;

import android.graphics.Bitmap;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.CustomIcon;
import com.newsblur.util.CustomIconRenderer;
import com.newsblur.util.UIUtils;

public class FolderReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        String folderName = fs.getFolderName();
        CustomIcon customIcon = BlurDatabaseHelper.getFolderIcon(folderName);
        if (customIcon != null) {
            int iconSize = UIUtils.dp2px(this, 24);
            Bitmap iconBitmap = CustomIconRenderer.renderIcon(this, customIcon, iconSize);
            if (iconBitmap != null) {
                UIUtils.setupToolbar(this, iconBitmap, folderName, false);
                return;
            }
        }
        UIUtils.setupToolbar(this, R.drawable.ic_folder_closed, folderName, false);
    }

}
