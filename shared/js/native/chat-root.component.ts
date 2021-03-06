import {Component, OnInit} from '@angular/core';
import {AppService} from './app.service';
import {States} from './js/cyph.im/enums';
import {AbstractSessionInitService} from './js/cyph/services/abstract-session-init.service';
import {ChatEnvService} from './js/cyph/services/chat-env.service';
import {ChatStringsService} from './js/cyph/services/chat-strings.service';
import {ChatService} from './js/cyph/services/chat.service';
import {CyphertextService} from './js/cyph/services/cyphertext.service';
import {DialogService} from './js/cyph/services/dialog.service';
import {EnvService} from './js/cyph/services/env.service';
import {FileService} from './js/cyph/services/file.service';
import {P2PService} from './js/cyph/services/p2p.service';
import {ScrollService} from './js/cyph/services/scroll.service';
import {SessionService} from './js/cyph/services/session.service';
import {StringsService} from './js/cyph/services/strings.service';
import {SessionInitService} from './session-init.service';


/**
 * Angular component for chat UI root to share services.
 */
@Component({
	providers: [
		ChatService,
		CyphertextService,
		FileService,
		P2PService,
		ScrollService,
		SessionService,
		{
			provide: AbstractSessionInitService,
			useClass: SessionInitService
		},
		{
			provide: EnvService,
			useClass: ChatEnvService
		},
		{
			provide: StringsService,
			useClass: ChatStringsService
		}
	],
	selector: 'cyph-chat-root',
	templateUrl: './templates/chat-root.html'
})
export class ChatRootComponent implements OnInit {
	/** @inheritDoc */
	public async ngOnInit () : Promise<void> {
		if (this.abstractSessionInitService.callType) {
			if (!this.p2pService.isSupported) {
				this.appService.state	= States.blank;

				await this.dialogService.alert({
					content: this.stringsService.p2pDisabledLocal,
					ok: this.stringsService.ok,
					title: this.stringsService.p2pTitle
				});

				self.close();

				return;
			}

			this.p2pService.preemptivelyInitiate();
		}


		this.sessionService.one(this.sessionService.events.abort).then(() => {
			self.onbeforeunload		= () => {};
			this.appService.state	= States.chat;
		});

		this.sessionService.one(this.sessionService.events.beginChatComplete).then(() => {
			self.onbeforeunload	= () => this.stringsService.disconnectWarning;

			if (this.abstractSessionInitService.callType && this.sessionService.state.isAlice) {
				this.p2pService.p2p.request(this.abstractSessionInitService.callType);
			}
		});

		this.sessionService.one(this.sessionService.events.beginWaiting).then(() => {
			this.appService.state	= States.waitingForFriend;
		});

		this.sessionService.one(this.sessionService.events.connect).then(() => {
			this.appService.state	= States.chat;

			if (this.abstractSessionInitService.callType) {
				this.dialogService.toast({
					content: this.abstractSessionInitService.callType === 'video' ?
						this.stringsService.p2pWarningVideoPassive :
						this.stringsService.p2pWarningAudioPassive
					,
					delay: 5000
				});
			}
		});
	}

	constructor (
		/** @ignore */
		private readonly abstractSessionInitService: AbstractSessionInitService,

		/** @ignore */
		private readonly appService: AppService,

		/** @ignore */
		private readonly dialogService: DialogService,

		/** @ignore */
		private readonly p2pService: P2PService,

		/** @ignore */
		private readonly sessionService: SessionService,

		/** @ignore */
		private readonly stringsService: StringsService,

		/** @see CyphertextService */
		public readonly cyphertextService: CyphertextService
	) {}
}
