package com.example;

public interface UserRepository {

    /**
     * ID로 사용자를 조회합니다.
     *
     * @param id 조회할 사용자의 ID입니다. null이 아니어야 합니다.
     * @return 조회된 User 객체를 반환합니다. 존재하지 않는 경우 null을 반환합니다.
     */
    User findById(Long id);

    /**
     * 사용자를 저장합니다.
     *
     * @param user 저장할 User 객체입니다. null이 아니어야 합니다.
     * @return 저장된 User 객체를 반환합니다.
     * @throws IllegalArgumentException user가 null인 경우 발생합니다.
     */
    User save(User user);

    /**
     * 모든 사용자 목록을 반환합니다.
     *
     * @return 모든 User 객체의 리스트를 반환합니다.
     */
    List<User> findAll();
}
