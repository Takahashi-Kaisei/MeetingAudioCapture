import Testing

func expectSamples(_ actual: [Float], _ expected: [Float], accuracy: Float = 0.0001) {
    #expect(actual.count == expected.count)
    for index in 0..<min(actual.count, expected.count) {
        #expect(abs(actual[index] - expected[index]) < accuracy)
    }
}
