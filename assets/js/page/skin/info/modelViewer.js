import { AmbientLight, Box3, PerspectiveCamera, Scene, Sphere, WebGLRenderer } from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls'
import { Model } from 'bridge-model-viewer'

export class CustomModelViewer {
  constructor(canvasElement, modelData, texturePath, options) {
    if (options.maxWidth) this.maxWidth = options.maxWidth
    if (options.maxHeight) this.maxHeight = options.maxHeight

    this.renderer = new WebGLRenderer({
      canvas: canvasElement,
      alpha: true,
      antialias: true
    })
    this.renderer.setPixelRatio(window.devicePixelRatio + 1)
    this.camera = new PerspectiveCamera(60, 1, 1, 500)

    this.camera.updateProjectionMatrix()
    this.controls = new OrbitControls(this.camera, canvasElement)
    this.controls.enableZoom = true
    this.controls.enablePan = false
    this.scene = new Scene()
    this.scene.add(new AmbientLight(0xffffffff, 0.98))
    this.model = new Model(modelData, texturePath)
    this.scene.add(this.model.getGroup())

    window.addEventListener('resize', this.onResize.bind(this))
    this.controls.addEventListener('change', () => this.requestRendering())

    this.onResize()
    this.loadedModel = this.loadModel().then(() => this.requestRendering())
  }

  async loadModel() {
    await this.model.create()
  }

  get width() {
    // the -20px is for the scrollbar..
    return Math.min(window.innerWidth - 20, this.maxWidth)
  }

  get height() {
    return Math.min(window.innerHeight, this.maxHeight)
  }

  render(checkShouldTick = true) {
    this.renderer.render(this.scene, this.camera)
    this.renderingRequested = false

    if (checkShouldTick && this.model.shouldTick) {
      this.model.tick()
      this.model.animator.winterskyScene?.updateFacingRotation(this.camera)
      this.requestRendering()
    }
  }

  requestRendering(immediate = false) {
    if (immediate) return this.render(false)

    if (this.renderingRequested) return

    this.renderingRequested = true
    requestAnimationFrame(() => this.render())
  }

  onResize() {
    this.renderer.setSize(this.width, this.height, true)
    this.camera.aspect = this.width / this.height
    this.positionCamera()
    this.requestRendering()
  }

  dispose() {
    window.removeEventListener('resize', this.onResize)
    this.controls.removeEventListener('change', this.requestRendering)
  }

  getModel() {
    return this.model
  }

  // From: https://github.com/mrdoob/three.js/issues/6784#issuecomment-315963625
  positionCamera(scale = 1.5, rotate = true) {
    if (rotate) this.model.getGroup().rotation.set(0, -135 * (Math.PI / 180), 0)

    const boundingSphere = new Box3()
      .setFromObject(this.model.getGroup())
      .getBoundingSphere(new Sphere())

    const objectAngularSize = ((this.camera.fov * Math.PI) / 180) * scale
    const distanceToCamera = boundingSphere.radius / Math.tan(objectAngularSize / 2)
    const len = Math.sqrt(Math.pow(distanceToCamera, 2) + Math.pow(distanceToCamera, 2))

    this.camera.position.set(len, boundingSphere.center.y, len)
    this.controls.update()

    this.camera.lookAt(boundingSphere.center)
    this.controls.target.set(
      boundingSphere.center.x,
      boundingSphere.center.y,
      boundingSphere.center.z
    )

    this.camera.updateProjectionMatrix()
  }
}