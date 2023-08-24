package com.newsblur.viewModel

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.newsblur.util.Session

class ItemListViewModel : ViewModel() {

    private val _nextSession = MutableLiveData<Session>()
    val nextSession: LiveData<Session> = _nextSession

    fun updateSession(session: Session) {
        _nextSession.value = session
    }
}