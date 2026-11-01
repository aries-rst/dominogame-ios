import SwiftUI

/// Full rules reference, pushed from the root screen's "Rules" button.
/// Covers general domino basics plus a detailed section per variant.
struct RulesView: View {
    @ObservedObject private var lang = AppLang.shared

    private let yard = Color(red: 0.17, green: 0.22, blue: 0.16)
    private let chalk = Color(red: 0.95, green: 0.94, blue: 0.88)
    private let brick = Color(red: 0.70, green: 0.27, blue: 0.20)
    private let olive = Color(red: 0.34, green: 0.40, blue: 0.26)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.22)

    var body: some View {
        ZStack {
            yard.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    ruleSection(
                        title: t("Partners (Kozel)", "Козёл"),
                        body: t(
                            "Played by 4 players in two fixed partnerships — you and your partner sit across from each other and win or lose together. A round starts with the holder of the double-six (or the highest double in the set) leading it; after that, play passes to the left, and on your turn you must play a tile from your hand onto either open end of the line if it matches, or pass if nothing fits — there is no drawing in this variant. A round ends when someone empties their hand (a \"domino\") or when all four players pass in a row with nobody able to move (a block). The round's loser is the pair holding tiles when it ends, or — on a block — whichever pair holds more pips; that losing pair adds the pips left in everyone's hands (plus the leading side's own pips on a domino-out) to their running score. The first pair to reach 101 points loses the match and is called the \"goats\" (козлы) — everyone else wins.",
                            "Играют 4 человека в двух постоянных парах — вы с партнёром сидите друг напротив друга и побеждаете или проигрываете вместе. Раунд начинает тот, у кого дубль-шесть (или старший дубль в комплекте); дальше ход идёт по кругу влево, и на своём ходу нужно сыграть костяшку, подходящую к любому открытому концу цепи, либо пропустить ход, если подходящей нет — добора в этом варианте нет. Раунд заканчивается, когда кто-то выкладывает последнюю костяшку («домино») или когда все четверо подряд пропускают и ходить некому (блок). Проигравшей считается пара, у которой на руках остались костяшки, либо — при блоке — та пара, у которой очков (точек) больше; эта пара добавляет к своему счёту очки, оставшиеся на руках у всех игроков (плюс очки выигравшей стороны при выходе «в домино»). Первая пара, набравшая 101 очко, проигрывает партию и становится «козлами» — остальные выигрывают."
                        )
                    )

                    ruleSection(
                        title: t("Block", "Блок"),
                        body: t(
                            "The simplest variant, for 2–4 players each playing for themselves, with no drawing at all. Tiles are dealt out and the first move is led by whoever holds the highest double (or, on later rounds, by the previous round's winner). On your turn, play a matching tile onto either open end, or pass immediately if you have nothing that fits. The round ends the moment a player empties their hand, or when every remaining player passes in succession and the game is blocked. If someone goes out, they score the total pips left in every opponent's hand. On a block, whoever is holding the fewest pips scores the difference between their hand and everyone else's combined. Rounds repeat, adding to each player's running total, until someone reaches the match target and wins.",
                            "Самый простой вариант для 2–4 игроков, каждый сам за себя, без добора. Костяшки раздаются, первый ход делает тот, у кого старший дубль (в следующих раундах — победитель предыдущего раунда). На своём ходу нужно сыграть подходящую костяшку на любой открытый конец или сразу пропустить ход, если подходящей нет. Раунд заканчивается, как только кто-то выкладывает последнюю костяшку, либо когда все оставшиеся игроки подряд пропускают и игра блокируется. Если игрок вышел «в домино», он получает очки за все костяшки, оставшиеся на руках у соперников. При блоке игрок с наименьшим числом очков на руках получает разницу между своими очками и суммой очков остальных. Раунды повторяются, очки копятся, пока кто-то не наберёт очков до цели партии и не выиграет."
                        )
                    )

                    ruleSection(
                        title: t("Draw", "С добором"),
                        body: t(
                            "Same basic flow as Block — 2–4 players, each for themselves — but with one key difference: if you can't play on your turn, you don't simply pass. Instead you draw tiles one at a time from the boneyard (the undealt tiles) until you draw one you can play, or until the boneyard is empty, at which point you pass as in Block. This keeps rounds going longer and rewards players who can hold flexible hands. Scoring and the win condition (going out, or a block once the boneyard runs dry, with pip-counting as in Block) work the same way as the Block variant, played up to the match's points target.",
                            "Тот же порядок, что и в «Блоке» — 2–4 игрока, каждый сам за себя, но с одним отличием: если нечем ходить, вы не пропускаете ход сразу. Вместо этого берёте костяшки по одной из базара (неразданных костяшек), пока не найдёте подходящую или пока базар не закончится — тогда пропуск хода, как в «Блоке». Это делает раунды длиннее и выгодно игрокам с гибкой рукой. Подсчёт очков и условие победы (выход «в домино» или блок, когда базар пуст, с подсчётом очков на руках как в «Блоке») такие же, как в варианте «Блок», до набора очков до цели партии."
                        )
                    )

                    ruleSection(
                        title: t("All Fives", "Пятёрки"),
                        body: t(
                            "For 2–4 players, each for themselves, with drawing from the boneyard just like Draw when you can't play. What's different is scoring: after every tile you play, if the pips on the open ends of the layout add up to a multiple of 5, you immediately score that many points — so a smart play can score points on nearly every turn, not just at the end of a round. The very first double played acts as a \"spinner\": it opens up to four arms instead of two, so later plays can branch in more directions and change which ends are open. A round still ends by someone going out or by a block, and any pips left over at that point are rounded to the nearest multiple of 5 and awarded to the winner on top of the running total — first to the match's points target wins.",
                            "Для 2–4 игроков, каждый сам за себя; добор из базара, когда нечем ходить — как в варианте «С добором». Отличие — в начислении очков: после каждого хода, если сумма очков на открытых концах цепи кратна 5, вы сразу получаете это количество очков — то есть удачный ход может приносить очки почти на каждом ходу, а не только в конце раунда. Первый сыгранный дубль становится «спиннером»: у него открываются не два, а четыре конца, так что дальнейшие ходы могут расходиться в разные стороны. Раунд всё равно заканчивается выходом «в домино» или блоком, а оставшиеся на момент окончания очки округляются до ближайшего кратного 5 и добавляются победителю к общему счёту — до набора очков до цели партии."
                        )
                    )
                }
                .padding(20)
            }
        }
        .navigationTitle(t("Rules", "Правила"))
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("How Domino Works", "Как играть в домино"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(chalk)
            Text(t(
                "This is classic double-six domino: a set of 28 tiles, each showing two numbers from 0 to 6 (every combination once, plus the seven doubles). Tiles are dealt into hands, and the rest form the boneyard. Play builds a single line of matching tiles: each new tile must show a number equal to the open end it's placed against. Every variant below shares this foundation — what differs is scoring, teams, and what happens when you can't move.",
                "Это классическое домино «дубль-шесть»: набор из 28 костяшек, на каждой — два числа от 0 до 6 (все сочетания по одному разу плюс семь дублей). Костяшки раздаются игрокам на руки, оставшиеся образуют базар. Игра строит единую цепочку из совпадающих костяшек: новая костяшка должна показывать число, равное открытому концу, к которому она приставляется. Все варианты ниже используют эту основу — различаются очки, команды и то, что происходит, если нечем ходить."
            ))
            .font(.subheadline)
            .foregroundStyle(chalk.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ruleSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(gold)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(chalk.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(olive.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(brick.opacity(0.4), lineWidth: 1))
        )
    }
}

#Preview {
    NavigationStack { RulesView() }
}
