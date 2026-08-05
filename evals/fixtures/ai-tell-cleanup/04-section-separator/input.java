package com.example;

public class ReportGenerator {

    // =============================================
    // Initialization
    // =============================================

    private final DataSource dataSource;

    public ReportGenerator(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    // --- Data Loading ---

    private List<Row> loadData(String query) {
        return dataSource.query(query);
    }

    // ########################################
    // Report Building
    // ########################################

    public Report build(String query) {
        List<Row> rows = loadData(query);
        return new Report(rows);
    }
}
