import { AmbientLight, AxesHelper, Box3, BoxHelper, GridHelper, PerspectiveCamera, Scene, Sphere, Vector3, WebGLRenderer } from 'three';
import { Model } from 'bridge-model-viewer';
import { IGeoSchema } from 'bridge-model-viewer/dist/Schema/Model';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

export interface IOptions {
  alpha?: boolean
  antialias?: boolean
  maxWidth?: number
  maxHeight?: number
}

export class CustomModelViewer {
  protected renderer: WebGLRenderer;
  protected model: Model;
  protected scene: Scene;
  protected camera: PerspectiveCamera;
  protected renderingRequested: boolean;
  protected controls: OrbitControls;
  public readonly loadedModel: Promise<void>;

  protected vector = new Vector3();

  constructor(
    protected canvasElement: HTMLCanvasElement,
    modelData: IGeoSchema,
    protected texturePath : string,
    protected options: IOptions
  ) {
    this.renderer = new WebGLRenderer({
      canvas: canvasElement,
      alpha: options.alpha ?? false,
      antialias: options.antialias ?? true
    })
    this.renderer.setPixelRatio(window.devicePixelRatio)
    this.camera = new PerspectiveCamera(60, 1, .1, 500)

    this.camera.updateProjectionMatrix()
    this.controls = new OrbitControls(this.camera, canvasElement)
    this.controls.enableZoom = true
    this.controls.enablePan = false
    this.scene = new Scene()
    this.scene.add(new AmbientLight(0xffffffff, .98))
    this.model = new Model(modelData, texturePath)
    this.scene.add(this.model.getGroup())

    const resize = new ResizeObserver(this.onResize.bind(this))

    this.controls.addEventListener('change', () => this.requestRendering())

    this.loadedModel = this.loadModel().then(() => {
      this.positionCamera()
      resize.observe(this.renderer.domElement, {box: 'content-box'})
    })
  }

  protected async loadModel() {
    await this.model.create()
  }

  protected render(checkShouldTick = true) {
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

  protected onResize() {
    const canvas = this.renderer.domElement;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;

    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()

    this.renderer.setSize(width, height, false)
    this.positionCamera()
    this.requestRendering(true)
  }

  dispose() {
    window.removeEventListener('resize', this.onResize)
    this.controls.removeEventListener('change', this.requestRendering)
  }

  addHelpers() {
    this.scene.add(new AxesHelper(50))
    this.scene.add(new GridHelper(20, 20))
    this.scene.add(new BoxHelper(this.model.getGroup(), 0xffff00))

    this.requestRendering()
  }

  getModel() {
    return this.model
  }

  // From: https://github.com/mrdoob/three.js/issues/6784#issuecomment-315963625
  positionCamera(scale = 1) {
    const boundingSphere = new Box3()
        .setFromObject(this.model.getGroup())
        .getBoundingSphere(new Sphere())

    const objectAngularSize = ((this.camera.fov * Math.PI) / 180) * scale
    const distanceToCamera = boundingSphere.radius / Math.tan(objectAngularSize / 2)
    const len = Math.sqrt(Math.pow(distanceToCamera, 2) * 2)

    this.model.getGroup().getWorldDirection(this.vector)
    this.vector.multiplyScalar(-len)
    this.vector.add(boundingSphere.center)

    this.camera.position.set(this.vector.x, this.vector.y, this.vector.z)
    this.controls.update()

    this.controls.target.set(
      boundingSphere.center.x,
      boundingSphere.center.y,
      boundingSphere.center.z
    )

    this.camera.updateProjectionMatrix()
  }
}