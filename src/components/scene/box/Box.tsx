import React, { useRef } from "react";
import { Box as ThreeBox } from "@react-three/drei";
import { ComponentProps } from "react";

interface IProps extends ComponentProps<typeof ThreeBox> {}

export function Box(props: IProps) {
  const boxRef = useRef();

  return (
    <ThreeBox ref={boxRef} {...props}>
      <meshNormalMaterial />
    </ThreeBox>
  );
}
