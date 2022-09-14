// vanilla cape geometry except for the rotation, as the back of the cape is the part that everyone wants to see initially
export const capeGeometry = {
  description: {
    identifier: "geometry.cape",
    texture_width: 64,
    texture_height: 32
  },
  bones: [
    {
      name: "body",
      pivot: [0.0, 24.0, 0.0],
      parent: "waist"
    },
    {
      name: "waist",
      pivot: [0.0, 12.0, 0.0]
    },
    {
      name: "cape",
      parent: "body",
      pivot: [0.0, 24.0, 3.0],
      //rotation: [0.0, 180.0, 0.0],
      cubes: [
        {
          origin: [-5.0, 8.0, 3.0],
          size: [10, 16, 1],
          uv: [0, 0]
        }
      ]
    }
  ]
}