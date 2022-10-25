import { CustomModelViewer } from "./render/custom_model_viewer";
import Wintersky from "wintersky";
import { alex, cape, steve } from "./render/models"

function getModel(modelName, geometry) {
    if (geometry && geometry != "") {
        return geometry
    }
    switch (modelName) {
        case "steve": return steve
        case "alex": return alex
        case "cape": return cape
        default: throw new Error("invalid model")
    }
}

const canvas = document.getElementById("renderTarget")

export const viewer = new CustomModelViewer(
    canvas,
    getModel(window.model, window.geometry),
    window.texture_url,
    {
        alpha: true,
        maxWidth: 500,
        maxHeight: 500
    }
)

async function setupViewer() {
    await viewer.loadedModel
    // viewer.addHelpers()

    const model = viewer.getModel()
    const winterskyScene = new Wintersky.Scene()
    winterskyScene.global_options.loop_mode = 'once'
    winterskyScene.global_options.scale = 16

    viewer.scene.add(winterskyScene.space)

    model.animator.setupWintersky(winterskyScene)
}

setupViewer()
