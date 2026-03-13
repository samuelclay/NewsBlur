package com.newsblur.util

import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.WindowManager
import android.widget.FrameLayout
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.newsblur.design.ReaderSheetPalette

object NewsBlurBottomSheet {
    @JvmStatic
    @JvmOverloads
    fun createDialog(
        fragment: androidx.fragment.app.DialogFragment,
        softInputMode: Int = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
    ): Dialog =
        BottomSheetDialog(fragment.requireContext()).apply {
            behavior.skipCollapsed = true
            behavior.isFitToContents = true
            window?.setSoftInputMode(softInputMode)
            window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        }

    @JvmStatic
    fun expandWithTheme(dialog: Dialog, theme: PrefConstants.ThemeValue) {
        val bottomSheetDialog = dialog as? BottomSheetDialog ?: return
        val bottomSheet =
            bottomSheetDialog.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet) ?: return

        bottomSheet.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(ReaderSheetPalette.backgroundArgb(theme))
            }
        bottomSheetDialog.behavior.state = BottomSheetBehavior.STATE_EXPANDED
    }
}
