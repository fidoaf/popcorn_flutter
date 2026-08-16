import 'package:popcorn_flutter/src/legal/domain/legal_document.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// Localized content for the public legal pages.
///
/// Popcorn is a non-commercial demo built for educational purposes, so the
/// wording is deliberately plain and reflects that context.
class LegalTranslations {
  LegalTranslations._();

  static const _lastUpdated = Translation({
    AppLanguage.en: 'Last updated: August 2026',
    AppLanguage.es: 'Última actualización: agosto de 2026',
    AppLanguage.ca: 'Última actualització: agost de 2026',
  });

  static const privacyPolicy = LegalDocument(
    title: Translation({AppLanguage.en: 'Privacy Policy', AppLanguage.es: 'Política de privacidad', AppLanguage.ca: 'Política de privadesa'}),
    lastUpdated: _lastUpdated,
    sections: [
      LegalSection(
        heading: Translation({AppLanguage.en: 'Overview', AppLanguage.es: 'Descripción general', AppLanguage.ca: 'Descripció general'}),
        body: Translation({
          AppLanguage.en:
              'Popcorn is a non-commercial demo application created for educational purposes. This policy explains what limited information the app handles and how it is used.',
          AppLanguage.es:
              'Popcorn es una aplicación de demostración sin fines comerciales creada con fines educativos. Esta política explica qué información limitada gestiona la aplicación y cómo se utiliza.',
          AppLanguage.ca:
              "Popcorn és una aplicació de demostració sense finalitats comercials creada amb finalitats educatives. Aquesta política explica quina informació limitada gestiona l'aplicació i com s'utilitza.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Information We Collect',
          AppLanguage.es: 'Información que recopilamos',
          AppLanguage.ca: 'Informació que recollim',
        }),
        body: Translation({
          AppLanguage.en:
              'When you sign in with Google we receive basic profile details such as your name, email address and avatar. This is only used to authenticate you. We do not collect any other personal information.',
          AppLanguage.es:
              'Cuando inicias sesión con Google recibimos datos básicos de tu perfil, como tu nombre, dirección de correo electrónico y avatar. Esto solo se usa para autenticarte. No recopilamos ninguna otra información personal.',
          AppLanguage.ca:
              "Quan inicies la sessió amb Google rebem dades bàsiques del teu perfil, com ara el teu nom, l'adreça de correu electrònic i l'avatar. Això només s'utilitza per autenticar-te. No recollim cap altra informació personal.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'How We Use Information',
          AppLanguage.es: 'Cómo usamos la información',
          AppLanguage.ca: 'Com fem servir la informació',
        }),
        body: Translation({
          AppLanguage.en:
              'Your profile details are used solely to keep you signed in and to personalize the experience. We never sell your data and we do not share it with third parties for advertising.',
          AppLanguage.es:
              'Los datos de tu perfil se utilizan únicamente para mantener tu sesión iniciada y personalizar la experiencia. Nunca vendemos tus datos ni los compartimos con terceros con fines publicitarios.',
          AppLanguage.ca:
              "Les dades del teu perfil s'utilitzen únicament per mantenir la teva sessió iniciada i personalitzar l'experiència. Mai venem les teves dades ni les compartim amb tercers amb finalitats publicitàries.",
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Local Storage', AppLanguage.es: 'Almacenamiento local', AppLanguage.ca: 'Emmagatzematge local'}),
        body: Translation({
          AppLanguage.en:
              'Your favorites and watch history are stored locally on your device. They stay under your control and are not uploaded to our servers.',
          AppLanguage.es:
              'Tus favoritos y tu historial de visualización se almacenan localmente en tu dispositivo. Permanecen bajo tu control y no se suben a nuestros servidores.',
          AppLanguage.ca:
              'Els teus preferits i el teu historial de visualització es guarden localment al teu dispositiu. Es mantenen sota el teu control i no es pugen als nostres servidors.',
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Third-Party Services', AppLanguage.es: 'Servicios de terceros', AppLanguage.ca: 'Serveis de tercers'}),
        body: Translation({
          AppLanguage.en:
              'The app relies on The Movie Database (TMDB) for media information, on external providers for streaming links, and on Google for sign-in. These services have their own privacy policies, which we encourage you to review.',
          AppLanguage.es:
              'La aplicación utiliza The Movie Database (TMDB) para la información multimedia, proveedores externos para los enlaces de reproducción y Google para el inicio de sesión. Estos servicios tienen sus propias políticas de privacidad, que te recomendamos revisar.',
          AppLanguage.ca:
              "L'aplicació utilitza The Movie Database (TMDB) per a la informació multimèdia, proveïdors externs per als enllaços de reproducció i Google per a l'inici de sessió. Aquests serveis tenen les seves pròpies polítiques de privadesa, que et recomanem revisar.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Data Retention and Deletion',
          AppLanguage.es: 'Conservación y eliminación de datos',
          AppLanguage.ca: 'Conservació i eliminació de dades',
        }),
        body: Translation({
          AppLanguage.en:
              'Signing out clears your session. You can remove locally stored data at any time by clearing the app data in your browser or device settings.',
          AppLanguage.es:
              'Al cerrar sesión se borra tu sesión. Puedes eliminar los datos almacenados localmente en cualquier momento borrando los datos de la aplicación en la configuración de tu navegador o dispositivo.',
          AppLanguage.ca:
              "En tancar la sessió s'esborra la teva sessió. Pots eliminar les dades emmagatzemades localment en qualsevol moment esborrant les dades de l'aplicació a la configuració del teu navegador o dispositiu.",
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: "Children's Privacy", AppLanguage.es: 'Privacidad de los menores', AppLanguage.ca: 'Privadesa dels menors'}),
        body: Translation({
          AppLanguage.en: 'This app is not directed to children under 13 and we do not knowingly collect information from them.',
          AppLanguage.es: 'Esta aplicación no está dirigida a menores de 13 años y no recopilamos información de ellos de forma intencionada.',
          AppLanguage.ca: 'Aquesta aplicació no està dirigida a menors de 13 anys i no recollim informació seva de manera intencionada.',
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Changes to This Policy',
          AppLanguage.es: 'Cambios en esta política',
          AppLanguage.ca: 'Canvis en aquesta política',
        }),
        body: Translation({
          AppLanguage.en: 'We may update this policy from time to time. Any changes will be reflected on this page.',
          AppLanguage.es: 'Podemos actualizar esta política periódicamente. Cualquier cambio se reflejará en esta página.',
          AppLanguage.ca: 'Podem actualitzar aquesta política periòdicament. Qualsevol canvi es reflectirà en aquesta pàgina.',
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Contact', AppLanguage.es: 'Contacto', AppLanguage.ca: 'Contacte'}),
        body: Translation({
          AppLanguage.en: 'For questions about this policy, please open an issue in the project repository.',
          AppLanguage.es: 'Para preguntas sobre esta política, abre una incidencia en el repositorio del proyecto.',
          AppLanguage.ca: 'Per a preguntes sobre aquesta política, obre una incidència al repositori del projecte.',
        }),
      ),
    ],
  );

  static const termsOfService = LegalDocument(
    title: Translation({AppLanguage.en: 'Terms of Service', AppLanguage.es: 'Términos del servicio', AppLanguage.ca: 'Termes del servei'}),
    lastUpdated: _lastUpdated,
    sections: [
      LegalSection(
        heading: Translation({AppLanguage.en: 'Acceptance of Terms', AppLanguage.es: 'Aceptación de los términos', AppLanguage.ca: 'Acceptació dels termes'}),
        body: Translation({
          AppLanguage.en: 'By using Popcorn you agree to these terms. If you do not agree, please do not use the app.',
          AppLanguage.es: 'Al usar Popcorn aceptas estos términos. Si no estás de acuerdo, no utilices la aplicación.',
          AppLanguage.ca: "En utilitzar Popcorn acceptes aquests termes. Si no hi estàs d'acord, no utilitzis l'aplicació.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Educational, Non-Commercial Use',
          AppLanguage.es: 'Uso educativo y no comercial',
          AppLanguage.ca: 'Ús educatiu i no comercial',
        }),
        body: Translation({
          AppLanguage.en:
              'Popcorn is a demonstration project built to showcase Flutter development. It is provided free of charge and is not intended for commercial use.',
          AppLanguage.es:
              'Popcorn es un proyecto de demostración creado para mostrar el desarrollo con Flutter. Se ofrece de forma gratuita y no está destinado a un uso comercial.',
          AppLanguage.ca:
              'Popcorn és un projecte de demostració creat per mostrar el desenvolupament amb Flutter. Es proporciona de manera gratuïta i no està destinat a un ús comercial.',
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Content and Third-Party Sources',
          AppLanguage.es: 'Contenido y fuentes de terceros',
          AppLanguage.ca: 'Contingut i fonts de tercers',
        }),
        body: Translation({
          AppLanguage.en:
              'Media information is provided by The Movie Database (TMDB) and is not endorsed or certified by them. Streaming links are supplied by third-party providers; the app does not host, upload or store any media content itself.',
          AppLanguage.es:
              'La información multimedia la proporciona The Movie Database (TMDB) y no está respaldada ni certificada por ellos. Los enlaces de reproducción los proporcionan proveedores externos; la aplicación no aloja, sube ni almacena ningún contenido multimedia.',
          AppLanguage.ca:
              "La informació multimèdia la proporciona The Movie Database (TMDB) i no està avalada ni certificada per ells. Els enllaços de reproducció els proporcionen proveïdors externs; l'aplicació no allotja, puja ni emmagatzema cap contingut multimèdia.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'User Responsibilities',
          AppLanguage.es: 'Responsabilidades del usuario',
          AppLanguage.ca: "Responsabilitats de l'usuari",
        }),
        body: Translation({
          AppLanguage.en: 'You agree to use the app in accordance with applicable laws and not to misuse it or attempt to disrupt its operation.',
          AppLanguage.es:
              'Aceptas usar la aplicación de acuerdo con las leyes aplicables y no hacer un uso indebido de ella ni intentar interrumpir su funcionamiento.',
          AppLanguage.ca:
              "Acceptes utilitzar l'aplicació d'acord amb les lleis aplicables i no fer-ne un ús indegut ni intentar interrompre'n el funcionament.",
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Intellectual Property', AppLanguage.es: 'Propiedad intelectual', AppLanguage.ca: 'Propietat intel·lectual'}),
        body: Translation({
          AppLanguage.en: 'All trademarks, logos and media artwork belong to their respective owners.',
          AppLanguage.es: 'Todas las marcas comerciales, logotipos y material gráfico pertenecen a sus respectivos propietarios.',
          AppLanguage.ca: 'Totes les marques comercials, logotips i material gràfic pertanyen als seus respectius propietaris.',
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Disclaimer of Warranties', AppLanguage.es: 'Renuncia de garantías', AppLanguage.ca: 'Renúncia de garanties'}),
        body: Translation({
          AppLanguage.en: 'The app is provided "as is" and "as available" without warranties of any kind, either express or implied.',
          AppLanguage.es: 'La aplicación se proporciona "tal cual" y "según disponibilidad", sin garantías de ningún tipo, ya sean expresas o implícitas.',
          AppLanguage.ca: 'L\'aplicació es proporciona "tal qual" i "segons disponibilitat", sense garanties de cap tipus, ja siguin expresses o implícites.',
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Limitation of Liability',
          AppLanguage.es: 'Limitación de responsabilidad',
          AppLanguage.ca: 'Limitació de responsabilitat',
        }),
        body: Translation({
          AppLanguage.en: 'To the fullest extent permitted by law, the authors are not liable for any damages arising from the use of this demo app.',
          AppLanguage.es:
              'En la máxima medida permitida por la ley, los autores no se hacen responsables de los daños derivados del uso de esta aplicación de demostración.',
          AppLanguage.ca:
              "En la màxima mesura permesa per la llei, els autors no es fan responsables dels danys derivats de l'ús d'aquesta aplicació de demostració.",
        }),
      ),
      LegalSection(
        heading: Translation({
          AppLanguage.en: 'Changes to These Terms',
          AppLanguage.es: 'Cambios en estos términos',
          AppLanguage.ca: 'Canvis en aquests termes',
        }),
        body: Translation({
          AppLanguage.en: 'We may revise these terms at any time. Continued use of the app after changes means you accept the updated terms.',
          AppLanguage.es:
              'Podemos revisar estos términos en cualquier momento. El uso continuado de la aplicación tras los cambios implica que aceptas los términos actualizados.',
          AppLanguage.ca:
              "Podem revisar aquests termes en qualsevol moment. L'ús continuat de l'aplicació després dels canvis implica que acceptes els termes actualitzats.",
        }),
      ),
      LegalSection(
        heading: Translation({AppLanguage.en: 'Contact', AppLanguage.es: 'Contacto', AppLanguage.ca: 'Contacte'}),
        body: Translation({
          AppLanguage.en: 'For questions about these terms, please open an issue in the project repository.',
          AppLanguage.es: 'Para preguntas sobre estos términos, abre una incidencia en el repositorio del proyecto.',
          AppLanguage.ca: 'Per a preguntes sobre aquests termes, obre una incidència al repositori del projecte.',
        }),
      ),
    ],
  );

  /// Footer links shown on the login screens.
  static const privacyLink = Translation({AppLanguage.en: 'Privacy Policy', AppLanguage.es: 'Política de privacidad', AppLanguage.ca: 'Política de privadesa'});

  static const termsLink = Translation({AppLanguage.en: 'Terms of Service', AppLanguage.es: 'Términos del servicio', AppLanguage.ca: 'Termes del servei'});
}
