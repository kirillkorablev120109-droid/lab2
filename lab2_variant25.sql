-- Лабораторная работа №2 «Создание запросов»
-- Вариант 25. Кораблёв Кирилл.
-- Требуется предварительно выполнить 01_lab1_variant25.sql.
-- Все изменения выполняются в отдельной производной таблице.

BEGIN;
SET LOCAL search_path TO korablev25;

-- 1. Вывести трек-номера для всей корреспонденции, отправленной в конвертах.
SELECT c.track_number
FROM correspondence AS c
JOIN correspondence_types AS t ON t.type_id = c.type_id
WHERE t.packaging = 'Конверт'
ORDER BY c.track_number;

-- 2. Вывести виды корреспонденции, для которых средние значения длины, ширины и
-- высоты являются пропорциональными.
-- Проверяем пропорцию: средняя длина / средняя ширина =
--                      средняя ширина / средняя высота.
-- Без деления на ноль эквивалентно: AVG(длина)*AVG(высота) = AVG(ширина)^2.
SELECT t.type_id, t.type_name, t.packaging,
       ROUND(AVG(c.length_cm), 2) AS avg_length_cm,
       ROUND(AVG(c.width_cm), 2) AS avg_width_cm,
       ROUND(AVG(c.height_cm), 2) AS avg_height_cm
FROM correspondence_types AS t
JOIN correspondence AS c ON c.type_id = t.type_id
GROUP BY t.type_id, t.type_name, t.packaging
HAVING ROUND(AVG(c.length_cm) * AVG(c.height_cm), 2)
     = ROUND(AVG(c.width_cm) * AVG(c.width_cm), 2)
ORDER BY t.type_id;

-- 3. Создать таблицу, содержащую данные 1 запроса с указанием веса, длины,
-- ширины и высоты, а также всей информации о видах корреспонденции.
DROP TABLE IF EXISTS envelope_selection_25;
CREATE TABLE envelope_selection_25 AS
SELECT c.track_number, c.type_id, c.weight_grams, c.length_cm,
       c.width_cm, c.height_cm, c.sender_code, c.stamps_amount,
       t.type_name, t.packaging, t.min_weight, t.max_weight,
       t.min_length, t.min_width, t.min_height,
       t.max_length, t.max_width, t.max_height
FROM correspondence AS c
JOIN correspondence_types AS t ON t.type_id = c.type_id
WHERE t.packaging = 'Конверт';
ALTER TABLE envelope_selection_25 ADD PRIMARY KEY (track_number);
SELECT * FROM envelope_selection_25 ORDER BY track_number;

-- 4. Добавить в созданную таблицу трек-номера посылок, длина, ширина или высота
-- которых выходит за рамки обусловленного диапазона.
INSERT INTO envelope_selection_25
(track_number, type_id, weight_grams, length_cm, width_cm, height_cm,
 sender_code, stamps_amount, type_name, packaging, min_weight, max_weight,
 min_length, min_width, min_height, max_length, max_width, max_height)
SELECT c.track_number, c.type_id, c.weight_grams, c.length_cm, c.width_cm,
       c.height_cm, c.sender_code, c.stamps_amount,
       t.type_name, t.packaging, t.min_weight, t.max_weight,
       t.min_length, t.min_width, t.min_height,
       t.max_length, t.max_width, t.max_height
FROM correspondence AS c
JOIN correspondence_types AS t ON t.type_id = c.type_id
WHERE t.type_name = 'Посылка'
  AND (
       c.length_cm NOT BETWEEN t.min_length AND t.max_length
    OR c.width_cm  NOT BETWEEN t.min_width  AND t.max_width
    OR c.height_cm NOT BETWEEN t.min_height AND t.max_height
  )
ON CONFLICT (track_number) DO NOTHING;
SELECT track_number, type_name, packaging, length_cm, width_cm, height_cm
FROM envelope_selection_25
WHERE type_name = 'Посылка'
ORDER BY track_number;

-- 5. В созданной таблице для всех посылок, упакованных в конверты и имеющих
-- дробный вес, увеличить все размеры на 1 см.
UPDATE envelope_selection_25
SET length_cm = length_cm + 1,
    width_cm = width_cm + 1,
    height_cm = height_cm + 1
WHERE type_name = 'Посылка'
  AND packaging = 'Конверт'
  AND weight_grams <> TRUNC(weight_grams);
SELECT track_number, weight_grams, length_cm, width_cm, height_cm
FROM envelope_selection_25
WHERE type_name = 'Посылка' AND packaging = 'Конверт'
ORDER BY track_number;

-- 6. Удалить все посылки, трек-номера которых содержат более одного пробела
-- в начале или конце номера.
DELETE FROM envelope_selection_25
WHERE type_name = 'Посылка'
  AND track_number ~ '(^ {2,})|( {2,}$)';
SELECT track_number, type_name FROM envelope_selection_25 ORDER BY track_number;

-- 7. Посчитать сколько различных видов упаковки использовалось для конвертов,
-- бандеролей и посылок.
-- Учитываются реально зарегистрированные отправления, а не пустые виды справочника.
SELECT COUNT(DISTINCT t.packaging) AS different_packaging_types
FROM correspondence AS c
JOIN correspondence_types AS t ON t.type_id = c.type_id
WHERE t.packaging = 'Конверт'
   OR t.type_name IN ('Бандероль', 'Посылка');

-- Дополнительно: расшифровка по группам для проверки группового запроса.
WITH categorized AS (
    SELECT 'Конверты' AS category, t.packaging
    FROM correspondence AS c
    JOIN correspondence_types AS t ON t.type_id = c.type_id
    WHERE t.packaging = 'Конверт'
    UNION ALL
    SELECT 'Бандероли', t.packaging
    FROM correspondence AS c
    JOIN correspondence_types AS t ON t.type_id = c.type_id
    WHERE t.type_name = 'Бандероль'
    UNION ALL
    SELECT 'Посылки', t.packaging
    FROM correspondence AS c
    JOIN correspondence_types AS t ON t.type_id = c.type_id
    WHERE t.type_name = 'Посылка'
)
SELECT category, COUNT(DISTINCT packaging) AS packaging_count
FROM categorized
GROUP BY category
ORDER BY category;

COMMIT;
