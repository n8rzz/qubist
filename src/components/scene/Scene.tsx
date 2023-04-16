import React from "react";
import { Box } from "./box/Box";
import { buildGameBoardSlotPositionMap, buildBoxPositionKey, calculateGameBoardSize } from "./scene.utils";

const ROW_AND_COLUMN_COUNT = 9;
const LEVEL_COUNT = 19;

interface IProps {}

export function Scene() {
  const gameBoardOutline = React.useMemo(() => calculateGameBoardSize(ROW_AND_COLUMN_COUNT, LEVEL_COUNT), []);
  const slotPositionMap = React.useMemo(() => buildGameBoardSlotPositionMap(ROW_AND_COLUMN_COUNT, LEVEL_COUNT), []);

  console.log("gameBoardOutline", gameBoardOutline);
  console.log("slotPositionMap", slotPositionMap);

  return (
    <>
      {/* <Box args={gameBoardOutline} rotation={[0, 0, 0]} position={[0, 0, 0]} />; */}
      {/* <Box args={[1, 1, 1]} rotation={[0, 0, 0]} position={[-4.725, -9.975, -4.725]} />; */}
      {slotPositionMap.map((levels: number[][][], levelIndex: number) => {
        return levels.map((rows: number[][], rowIndex: number) => {
          return rows.map((row: number[], colIndex: number) => {
            const key = buildBoxPositionKey(levelIndex, rowIndex, colIndex);
            // order is important here, values are correct but names may be wrong
            const [x, y, z] = row;

            return <Box key={key} args={[1, 1, 1]} rotation={[0, 0, 0]} position={[x, y, z]} />;
          });
        });
      })}
      <ambientLight />
    </>
  );
}
