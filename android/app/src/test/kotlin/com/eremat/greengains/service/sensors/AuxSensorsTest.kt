package com.eremat.greengains.service.sensors

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AuxSensorsTest {
    @Test fun emptyWindowHasNoValue() = assertNull(medianOf(emptyList()))

    @Test fun singleSampleIsItself() = assertEquals(21.5f, medianOf(listOf(21.5f))!!, 0f)

    @Test fun oddCountTakesMiddle() = assertEquals(3f, medianOf(listOf(9f, 1f, 3f))!!, 0f)

    @Test fun evenCountAveragesTheTwoMiddle() = assertEquals(2.5f, medianOf(listOf(4f, 1f, 3f, 2f))!!, 0f)

    @Test fun oneSpikeDoesNotMoveIt() {
        // A stray 10 000 among steady ~100 lux must not drag the reading.
        val m = medianOf(listOf(100f, 101f, 99f, 10_000f, 100f, 102f, 98f))!!
        assertEquals(100f, m, 0f)
    }

    @Test fun doesNotMutateItsInput() {
        val input = listOf(3f, 1f, 2f)
        medianOf(input)
        assertEquals(listOf(3f, 1f, 2f), input)
    }
}
