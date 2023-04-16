import { BOX_SPACING } from "./scene.constants";

function _calculateBoxPointWithSpacing(coordinate: number, originTranslationValue: number): number {
  return coordinate + Math.abs(coordinate) * BOX_SPACING + originTranslationValue;
}

export function _buildGameBoardSlotPositionMap(rowsAndColumns: number, levels: number): number[][][][] {
  const [originX, originY, originZ] = calculateGameBoardSize(rowsAndColumns, levels);
  const translatedLevelOrigin = (originX / 2) * -1;
  const translatedColumnOrigin = (originY / 2) * -1;
  const translatedRowOrigin = (originZ / 2) * -1;
  const slotPositionMap: number[][][][] = [];

  console.log("translated origin", translatedLevelOrigin, translatedColumnOrigin, translatedRowOrigin);

  for (let l = 0; l <= levels; l++) {
    const level: number[][][] = [];

    for (let r = 0; r <= rowsAndColumns; r++) {
      const row: number[][] = [];

      for (let c = 0; c <= rowsAndColumns; c++) {
        // this might actually be `y` need to check docs
        const x = _calculateBoxPointWithSpacing(c, 0);
        const z = _calculateBoxPointWithSpacing(r, translatedRowOrigin);
        // this might actually be `x` need to check docs
        const y = _calculateBoxPointWithSpacing(l, translatedLevelOrigin);
        const point = [x, y, z];

        row.push(point);
      }

      level.push(row);
    }

    slotPositionMap.push(level);
  }

  return slotPositionMap;
}

export function buildGameBoardSlotPositionMap(rowsAndColumns: number, levels: number): number[][][][] {
  const slotPositionMap: number[][][][] = _buildGameBoardSlotPositionMap(rowsAndColumns, levels);

  return slotPositionMap;
}

export function buildBoxPositionKey(levelIndex: number, rowIndex: number, colIndex: number): string {
  return `${levelIndex}-${rowIndex}-${colIndex}`;
}

export function calculateGameBoardSize(rowsAndCOlumns: number, levels: number): number[] {
  const width = rowsAndCOlumns + rowsAndCOlumns * BOX_SPACING;
  const height = levels + levels * BOX_SPACING;
  const depth = rowsAndCOlumns + rowsAndCOlumns * BOX_SPACING;

  return [width, height, depth];
}
