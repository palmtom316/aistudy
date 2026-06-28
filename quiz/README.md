# quiz/

题目原子，回链 notes/。一文件一题，文件名 `<topic>-<序号>.md`。

`study-quiz` skill 自动维护 `correct / status / last_attempted`，并回写对应 notes 的 mastery。

错题（`correct: false`）会被 `study-drill` 纳入"待重做"清单。
