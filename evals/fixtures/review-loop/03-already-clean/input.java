package com.example;

import org.springframework.stereotype.Service;

@Service
public class ProductService {

    private final ProductRepository repository;

    public ProductService(ProductRepository repository) {
        this.repository = repository;
    }

    public Product findById(Long id) {
        return repository.findById(id).orElseThrow();
    }

    public Product save(Product product) {
        return repository.save(product);
    }
}
