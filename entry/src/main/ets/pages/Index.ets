import camera from '@ohos.multimedia.camera';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';

@Entry
@Component
struct Index {
  @State surfaceId: string = '';
  @State isCameraActive: boolean = false;
  @State isMirrored: boolean = false;
  @State rotationAngle: number = 0;
  @State cameraDeviceIndex: number = 0;

  private cameraManager: camera.CameraManager | undefined = undefined;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private session: camera.CaptureSession | undefined = undefined;
  private cameras: Array<camera.CameraDevice> = [];
  private xComponentController: XComponentController = new XComponentController();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear() {
    await this.requestPermissions();
  }

  async requestPermissions() {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const grantStatus = await atManager.requestPermissionsFromUser(this.context, ['ohos.permission.CAMERA']);
      if (grantStatus.authResults[0] === 0) {
        console.info('Camera permission granted');
        this.initCamera();
      } else {
        console.error('Camera permission denied');
      }
    } catch (err) {
      console.error('Failed to request permissions', JSON.stringify(err));
    }
  }

  async initCamera() {
    try {
      this.cameraManager = camera.getCameraManager(this.context);
      if (!this.cameraManager) {
        console.error('Failed to get camera manager');
        return;
      }

      this.cameras = this.cameraManager.getSupportedCameras();
      if (this.cameras.length === 0) {
        console.error('No camera devices found');
        return;
      }
      
      // Attempt to find front camera as default for "Mirror" app
      const frontCameraIndex = this.cameras.findIndex(c => c.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT);
      if (frontCameraIndex !== -1) {
        this.cameraDeviceIndex = frontCameraIndex;
      }

      if (this.surfaceId) {
        // If surface is already ready (e.g. permission granted after XComponent loaded)
        // We can start, but let's wait for user action or start automatically if preferred
        // For this app, let's start automatically like the web version
        this.startCamera();
      }
    } catch (error) {
      console.error('Failed to init camera', JSON.stringify(error));
    }
  }

  async startCamera() {
    if (this.isCameraActive) return;
    if (!this.cameraManager || this.cameras.length === 0) return;

    try {
      let cameraDevice = this.cameras[this.cameraDeviceIndex];
      this.cameraInput = this.cameraManager.createCameraInput(cameraDevice);
      await this.cameraInput.open();

      // Get supported output capability
      let capability = this.cameraManager.getSupportedOutputCapability(cameraDevice, camera.SceneMode.CAPTURE);
      let previewProfile = capability.previewProfiles[0];
      
      this.previewOutput = this.cameraManager.createPreviewOutput(previewProfile, this.surfaceId);

      this.session = this.cameraManager.createCaptureSession();
      this.session.beginConfig();
      this.session.addInput(this.cameraInput);
      this.session.addOutput(this.previewOutput);
      await this.session.commitConfig();
      await this.session.start();

      this.isCameraActive = true;
      
      // Auto-mirror if front camera
      if (cameraDevice.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        this.isMirrored = true;
      } else {
        this.isMirrored = false;
      }

    } catch (error) {
      console.error('Failed to start camera', JSON.stringify(error));
    }
  }

  async stopCamera() {
    if (!this.isCameraActive) return;
    try {
      await this.session?.stop();
      await this.session?.release();
      await this.cameraInput?.close();
      await this.cameraInput?.release();
      await this.previewOutput?.release();
      
      this.session = undefined;
      this.cameraInput = undefined;
      this.previewOutput = undefined;
      this.isCameraActive = false;
    } catch (error) {
      console.error('Failed to stop camera', JSON.stringify(error));
    }
  }

  async switchCamera() {
    await this.stopCamera();
    this.cameraDeviceIndex = (this.cameraDeviceIndex + 1) % this.cameras.length;
    await this.startCamera();
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Bottom }) {
        XComponent({
          id: 'cameraXComponent',
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
          .onLoad(() => {
            this.surfaceId = this.xComponentController.getXComponentSurfaceId();
            if (this.cameraManager) {
               this.startCamera();
            }
          })
          .width('100%')
          .height('100%')
          .rotate({ angle: this.rotationAngle })
          .scale({ x: this.isMirrored ? -1 : 1, y: 1 })

        // Controls Container
        Column() {
          // Status Info (Resolution etc. - mocked for now or get from profile)
          Text('相机预览中')
            .fontColor(Color.White)
            .fontSize(12)
            .backgroundColor('#66000000')
            .padding(5)
            .borderRadius(5)
            .margin({ bottom: 20 })
            .visibility(this.isCameraActive ? Visibility.Visible : Visibility.Hidden)

          // Button Groups
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
            Button($r('app.string.start_camera'))
              .onClick(() => this.startCamera())
              .enabled(!this.isCameraActive)
              .margin(5)
              .height(40)
              .fontSize(14)
            
            Button($r('app.string.stop_camera'))
              .onClick(() => this.stopCamera())
              .enabled(this.isCameraActive)
              .backgroundColor(Color.Red)
              .margin(5)
              .height(40)
              .fontSize(14)

            Button($r('app.string.flip_camera'))
              .onClick(() => {
                this.isMirrored = !this.isMirrored;
              })
              .margin(5)
              .height(40)
              .fontSize(14)
              
            Button($r('app.string.rotate_camera'))
              .onClick(() => {
                this.rotationAngle = (this.rotationAngle + 90) % 360;
              })
              .margin(5)
              .height(40)
              .fontSize(14)

            Button($r('app.string.switch_camera'))
              .onClick(() => {
                this.switchCamera();
              })
              .margin(5)
              .height(40)
              .fontSize(14)
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#80000000')
          .borderRadius(20)
        }
        .width('90%')
        .margin({ bottom: 30 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
    }
    .width('100%')
    .height('100%')
  }
}
