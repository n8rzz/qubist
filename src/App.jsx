import React from "react";
import { Canvas } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { Scene } from "./components/scene/Scene";

const App = () => {
  return (
    <Canvas camera={{ fov: 50, position: [-5, 10, 25] }}>
      <OrbitControls />
      <Scene />
    </Canvas>
  );
};

export default App;
