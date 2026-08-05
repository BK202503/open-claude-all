package com.example

import org.springframework.stereotype.Service

@Service
class UserService(private val repo: UserRepository) {

    fun findById(id: Long): User? {
        // ID로 사용자를 조회한다
        val user = repo.findById(id).orElse(null)
        // 결과를 반환한다
        return user
    }

    fun save(user: User): User {
        // 유저를 저장한다
        return repo.save(user)
    }

    fun deleteById(id: Long) {
        // 해당 ID의 유저를 삭제한다
        repo.deleteById(id)
    }
}
