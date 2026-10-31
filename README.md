# libreria-ejemplo

Librería Java de ejemplo para probar un flujo CI/CD privado:
Bitbucket (código) → Jenkins (build, pruebas, SonarQube) → Nexus (versiones privadas) → réplica en GitHub → publicación manual en Maven Central.

## Uso

```xml
<dependency>
  <groupId>io.github.carlosastrea</groupId>
  <artifactId>libreria-ejemplo</artifactId>
  <version>1.0.0</version>
</dependency>
```

```java
Textos.saludar("Ana");                    // "Hola, Ana!"
Textos.esPalindromo("Anita lava la tina"); // true
```

## Ramas

- `develop`: rama principal. Cada merge publica una versión nueva (`vX.Y.Z`).
- `feature/<nombre>`: se valida en Jenkins y abre un PR hacia `develop`.

## Construir en local

```bash
mvn verify -Drevision=1.0.0
```

Licencia: Apache-2.0.
