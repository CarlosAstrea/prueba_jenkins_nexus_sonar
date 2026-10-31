package io.github.carlosastrea.ejemplo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class TextosTest {

    @Test
    void saludaPorNombre() {
        assertEquals("Hola, Ana!", Textos.saludar("Ana"));
    }

    @Test
    void rechazaNombreNulo() {
        assertThrows(IllegalArgumentException.class, () -> Textos.saludar(null));
    }

    @Test
    void rechazaNombreEnBlanco() {
        assertThrows(IllegalArgumentException.class, () -> Textos.saludar("  "));
    }

    @Test
    void detectaPalindromoIgnorandoMayusculasYEspacios() {
        assertTrue(Textos.esPalindromo("Anita lava la tina"));
    }

    @Test
    void detectaQueNoEsPalindromo() {
        assertFalse(Textos.esPalindromo("hola"));
    }
}
