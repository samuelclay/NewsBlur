package com.newsblur.widget;

import android.appwidget.AppWidgetManager;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.RemoteViews;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.util.Log;

public class ConfigureWidgetActivity extends NbActivity {
    private int appWidgetId;

    private static String TAG = "ConfigureWidgetActivity";
    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        setContentView(R.layout.activity_configure_widget);

        Intent intent = getIntent();
        Bundle extras = intent.getExtras();
        if (extras != null) {
            appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);
        }

        Button btnSaveWidget = findViewById(R.id.btn_save);

        btnSaveWidget.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                saveWidget();
            }
        });

        // set result as cancelled in the case that we don't finish config
        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
//        setResult(RESULT_CANCELED, resultValue);
    }


    private void saveWidget(){
        //update widget
        Log.d(TAG, "saveWidget");
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
        RemoteViews rv = new RemoteViews(getPackageName(),
                R.layout.newsblur_widget);

        Intent intent = new Intent(this, BlurWidgetRemoteViewsService.class);
        // Add the app widget ID to the intent extras.
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);

        rv.setRemoteAdapter(R.id.widget_list, intent);
        rv.setEmptyView(R.id.widget_list, R.id.empty_view);

        appWidgetManager.updateAppWidget(appWidgetId, rv);


        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        setResult(RESULT_OK, resultValue);
        finish();
    }
}
