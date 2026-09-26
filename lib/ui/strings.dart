import '../engine/entities.dart';
import '../engine/world.dart';

/// Every word the cabinet says, in one place.
///
/// The engine names events (`NoticeCode.targetHit`, `VesselClass.destroyer`)
/// and never builds a sentence; turning those into Russian is this file's job
/// and nobody else's. When a second language or a second campaign shows up,
/// it is this file that gets an alternative — not `world.dart`.
class Ru {
  const Ru._();

  static const title = 'МОРСКОЙ БОЙ';
  static const windowTitle = 'Морской бой';

  static const score = 'СЧЁТ';
  static const best = 'РЕКОРД';
  static const sound = 'ЗВУК';
  static const gear = 'ПРИВОД';
  static const torpedoes = 'ТОРПЕДЫ';
  static const fire = 'ТОРПЕДА';
  static const threat = 'УГРОЗА';
  static const alarm = 'ТРЕВОГА';
  static const target = 'ЦЕЛЬ';
  static const lock = 'ЗАХВАТ';
  static const bearingLabel = 'ПЕЛЕНГ';
  static const hitsLabel = 'ПОПАДАНИЯ';
  static const ready = 'ГОТОВ';
  static const neutralFlag = 'НЕЙТРАЛ';
  static const enemyFlag = 'ВРАГ';
  static const noTarget = 'НЕТ ЦЕЛИ';
  static const stop = 'УПОР';
  static const bow = 'НОС';

  static const dive = 'ПОГРУЖЕНИЕ';
  static const again = 'ЕЩЁ РАЗ';
  static const patrolOver = 'ОТБОЙ';
  static const points = 'ОЧКИ';
  static const hitsOfShots = 'ПОПАДАНИЙ';
  static const accuracy = 'ТОЧНОСТЬ';
  static const hullHits = 'ПОПАДАНИЙ В ЛОДКУ';
  static const neutralsSunk = 'НЕЙТРАЛОВ ПОТОПЛЕНО';

  static const briefing =
      'Наводи перископ штурвалом или стрелками. Торпеда идёт долго: стреляй '
      'туда, где цель будет, а не туда, где она есть.\n\n'
      'Держи судно в окуляре, пока не прочтёшь флаг: нейтрала топить нельзя, '
      'это минус очки. Под лентой пеленгов — шкала всего сектора, красные '
      'отметки на ней это охотники и мины. После их бомб привод наводки '
      'навсегда начинает ходить по инерции.';

  static const keyHints = '← → ПОВОРОТ    ПРОБЕЛ ЗАЛП    M ЗВУК    R ЗАНОВО';

  /// Bearing readout in the header: «ПЕЛЕНГ Л15°».
  static String bearing(double degrees) {
    final side = degrees < -0.5 ? 'Л' : (degrees > 0.5 ? 'П' : '');
    return 'ПЕЛЕНГ $side${degrees.abs().round()}°';
  }

  /// Bearing on an instrument counter: «Л015», «П120», «000».
  static String bearingCounter(double degrees) {
    final rounded = degrees.round();
    final side = rounded < 0 ? 'Л' : (rounded > 0 ? 'П' : ' ');
    return '$side${rounded.abs().toString().padLeft(3, '0')}';
  }

  /// Marks on the bearing tape: «Л15», «НОС», «П30».
  static String bearingMark(int degrees) =>
      degrees == 0 ? bow : '${degrees < 0 ? 'Л' : 'П'}${degrees.abs()}';

  static String vessel(VesselClass type) => switch (type) {
    VesselClass.patrolBoat => 'КАТЕР',
    VesselClass.submarine => 'ПОДЛОДКА',
    VesselClass.destroyer => 'ЭСМИНЕЦ',
    VesselClass.cruiser => 'КРЕЙСЕР',
    VesselClass.freighter => 'ТРАНСПОРТ',
    VesselClass.tanker => 'ТАНКЕР',
  };

  static String notice(Notice notice) => switch (notice.code) {
    NoticeCode.searching => 'ПОИСК ЦЕЛИ',
    NoticeCode.tubesReady => 'ТОРПЕДЫ ГОТОВЫ',
    NoticeCode.reloading => 'ПЕРЕЗАРЯДКА',
    NoticeCode.missed => 'МИМО',
    NoticeCode.mineDestroyed => 'МИНА!',
    NoticeCode.bombing => 'БОМБЁЖКА',
    NoticeCode.depthChargeHit => 'ГЛУБИННАЯ БОМБА',
    NoticeCode.mineAlongside => 'МИНА У БОРТА',
    NoticeCode.hullStruck => 'УДАР ПО КОРПУСУ',
    NoticeCode.ammoOut => 'БОЕЗАПАС ИЗРАСХОДОВАН',
    NoticeCode.targetHit => _sunk(notice),
    NoticeCode.neutralSunk => _neutralSunk(notice),
    NoticeCode.neutralIdentified => 'НЕЙТРАЛ — НЕ ТОПИТЬ',
    NoticeCode.enemyIdentified => _flagRead(notice),
  };

  /// The penalty comes with the notice, so the number lives in the rules and
  /// only the wording is here.
  static String _neutralSunk(Notice notice) {
    final points = notice.points;
    return points == null
        ? 'НЕЙТРАЛ ПОТОПЛЕН'
        : 'НЕЙТРАЛ ПОТОПЛЕН ${points < 0 ? '−' : '+'}${points.abs()}';
  }

  static String _flagRead(Notice notice) {
    final type = notice.vessel;
    return type == null ? 'ЦЕЛЬ ОПОЗНАНА' : '${vessel(type)} — ЦЕЛЬ';
  }

  static String _sunk(Notice notice) {
    final type = notice.vessel;
    final points = notice.points;
    if (type == null) return 'ПОПАДАНИЕ';
    return points == null
        ? vessel(type)
        : '${vessel(type)} +$points';
  }
}
