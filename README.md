Video Demo: https://drive.google.com/file/d/1lfwy2m-5HjlnkCktTRCfVFTTxwkzY05e/view?usp=sharing

Aplicación de pomodoro con compañero animado. Permite configurar la duración de trabajo  descanso, así como registrar el avance de un "ciclo completo", tradicionalmente considerado como 4 pomodoros.

Se usó flutter_launcher_icons para generar el ícono de la app

Los assets se encuentran en la carpeta del mismo nombre. La subcarpeta de sprites tiene las imágenes correspondientes a las animaciones, mientras que emptycat y filledcat se utilizan para representar el avance de los pomodoros.

La estructura general es:
- lib
	- main.dart
- assets
	- icon
	- sprites
		- shime1.png
		- shime2.png
		- ....
	- emptycat.png
	- filledcat.png
- pubspec.yaml
- README.md

Los archivos principales son los siguientes:
- main.dart- contiene la aplicación, estados, lógica del temporizador, animaciones y los diferentes widgets
- pubspec.yaml - Dependencias, assets e iconos

En cuestiones de la ejecución de la aplicación, empieza con PomodoroApp, la cuál configura el título, la pantalla inicial (PomodoroScreen) y el tema de la aplicación.

PomodoroScreen es un StatefulWidget, ya que hay cambios en esta. Muestra el encabezado del texto, los diferentes estados de la sesión, el gatito animado así como el temporizador. Incluye también el campo de texto donde se corre la tarea actual, y el contador de cuatro pomodoros.

Para el control del tiempo, se utiliza startTimer para iniciar o reanudar la cuenta regresiva, mientras que pauseTimer pausa el flujo temporal. onTimerComplete coordina el cambio entre el modo de trabajo y el de descanso, así como el contador de avance de pomodoros.

showTimerConfigDialog permite abrir el campo donde se configuran las duraciones, mientras que buildProgressRing se encarga del anillo en torno del temporizador. 

buildControls se responsabiliza de los botones de abajo, y buildPomodoroTracker construye los pomodoros de avance.

startSpriteAnimation ejecuta la animación del gatito, dependiendo del estado:
- Idle - Reposo
- workTransitionIn - Animación de entrada al modo trabajo
- working - Animación durante el trabajo
- workTransitionOut - Animación de salida del modo trabajo
- restTransitionIn - Animación de entrada al modo descanso
-  resting - Animación durante el modo descanso
- restTransitionOut - Animación de salida del modo descanso.


