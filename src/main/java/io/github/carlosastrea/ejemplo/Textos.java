package io.github.carlosastrea.ejemplo;

import java.util.Locale;

/** Utilidades de texto de ejemplo. */
public final class Textos {

    private Textos() {
    }

    /**
     * Devuelve un saludo para el nombre indicado.
     *
     * @param nombre nombre de la persona; no puede ser nulo ni estar en blanco
     * @return el saludo, por ejemplo {@code "Hola, Ana!"}
     * @throws IllegalArgumentException si el nombre es nulo o está en blanco
     */
    public static String saludar(String nombre) {
        if (nombre == null || nombre.trim().isEmpty()) {
            throw new IllegalArgumentException("El nombre no puede estar vacío");
        }
        return "Hola, " + nombre.trim() + "!";
    }

    /**
     * Indica si el texto se lee igual al derecho y al revés, sin contar
     * espacios ni mayúsculas.
     *
     * @param texto texto a evaluar; nulo se considera no palíndromo
     * @return {@code true} si es palíndromo
     */
    public static boolean esPalindromo(String texto) {
        if (texto == null) {
            return false;
        }
        String limpio = texto.replaceAll("\\s+", "").toLowerCase(Locale.ROOT);
        return new StringBuilder(limpio).reverse().toString().equals(limpio);
    }
}
