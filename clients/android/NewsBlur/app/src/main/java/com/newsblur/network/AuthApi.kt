package com.newsblur.network

import com.newsblur.network.domain.LoginResponse
import com.newsblur.network.domain.RegisterResponse

interface AuthApi {
    suspend fun login(username: String, password: String): LoginResponse
    suspend fun loginAs(username: String): Boolean
    suspend fun signup(username: String, password: String, email: String): RegisterResponse

}