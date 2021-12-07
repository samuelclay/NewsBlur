package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.ActionMode;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.Toast;

import androidx.appcompat.widget.AppCompatEditText;

import com.newsblur.R;

public class SelectOnlyEditText extends AppCompatEditText {

    private Context context;
    private boolean forceSelection = false;
    private String selection;

    public SelectOnlyEditText(Context context) {
        super(context);
        this.context = context;
    }

    public SelectOnlyEditText(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.context = context;
    }

    public SelectOnlyEditText(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.context = context;
    }

    public void disableActionMenu() {
        this.setCustomSelectionActionModeCallback(new ActionMode.Callback() {
            public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
                menu.clear();
                return true;
            }
            public void onDestroyActionMode(ActionMode mode) {                  
            }
            public boolean onCreateActionMode(ActionMode mode, Menu menu) {
                // note: calling menu.clear() here to ensure an empty menu totally breaks selection
                // on pre-N devices.
                return true;
            }
            public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
                return false;
            }
        });
    }

    public void setForceSelection(boolean forceSelection) {
        this.forceSelection = forceSelection;
    }

    @Override
    protected void onSelectionChanged(int start, int end) {
        super.onSelectionChanged(start, end);
        if (forceSelection && (start == end)) {
            selectAll();
            if (context != null) {
                Toast.makeText(context, R.string.toast_hold_to_select, Toast.LENGTH_SHORT).show();
            }
        }
        if (end > start) {
            this.selection = getText().toString().substring(start, end);
        } else {
            this.selection = null;
        }
    }

    public String getSelection() {
        return this.selection;
    }
}
