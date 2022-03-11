/* Copyright (C) 2022 Wyrd (https://github.com/wyrdwinter)

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>. */

'use strict'

import React, { useCallback, useState } from '../njs/node_modules/react'
import ReactDOM from '../njs/node_modules/react-dom'
import styled from '../njs/node_modules/styled-components'
import { useDropzone } from '../njs/node_modules/react-dropzone'
import Modal, { ModalProvider, BaseModalBackground } from '../njs/node_modules/styled-react-modal'

const CharacterUploadModal = Modal.styled`
  width: 60rem;
  max-width: 60rem;
  border: 3px solid #535892;
  border-radius: 0.5rem;
  background-color: rgb(25, 25, 25);
  box-shadow: 0 .5em 1em -0.125em rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(0, 0, 0, 0.32);
  color: rgb(200, 200, 200);
  opacity: ${(props) => props.opacity};
  transition : all 0.3s ease-in-out;
`

const CharacterUploadModalBackground = styled(BaseModalBackground)`
  opacity: ${(props) => props.opacity};
  transition: all 0.3s ease-in-out;
`

const CharacterUploadContainer = () => {
  // Constants

  const exposureList = [
    ['public', 'Public'],
    ['unlisted', 'Unlisted']
  ]

  const expirationList = [
    ['never', 'Never'],
    ['10-minutes', '10 Minutes'],
    ['1-hours', '1 Hour'],
    ['1-days', '1 Day'],
    ['1-weeks', '1 Week'],
    ['1-months', '1 Month'],
    ['6-months', '6 Months'],
    ['1-years', '1 Year']
  ]

  const serverList = [
    ['nwn', 'NWN Diamond'],
    ['sinfar', 'Sinfar']
  ]

  const tagList = {
    nwn: {
      type: [
        'Offensive Melee',
        'Defensive Melee',
        'Offensive Ranged',
        'Defensive Ranged',
        'Stealth',
        'Tank',
        'Nuke Caster',
        'Control Caster',
        'Support Caster',
        'Healer',
        'Arcane Spellsword',
        'Divine Spellsword',
        'Shapeshifter'
      ],
      features: [
        'Stunning Fist',
        'Terrifying Rage',
        'Bard Song',
        'Stun Resistant'
      ],
      purpose: [
        'PvP',
        'PvE',
        'Roleplaying'
      ]
    },
    sinfar: {
      type: [
        'Offensive Melee',
        'Defensive Melee',
        'Offensive Ranged',
        'Defensive Ranged',
        'Stealth',
        'Tank',
        'Nuke Caster',
        'Control Caster',
        'Support Caster',
        'Healer',
        'Arcane Spellsword',
        'Divine Spellsword',
        'Shapeshifter'
      ],
      features: [
        'Stunning Fist',
        'Terrifying Rage',
        'Bard Song',
        'Stun Resistant'
      ],
      purpose: [
        'PvP',
        'PvP: Open World',
        'PvP: CTF',
        'PvP: Duel',
        'PvE',
        'PvE: Farming',
        'PvE: Shard Run',
        'Roleplaying'
      ]
    }
  }

  // State

  const [isModalOpen, setIsModalOpen] = useState(false)
  const [modalOpacity, setModalOpacity] = useState(0)
  const [currentStep, setCurrentStep] = useState(0)

  const [file, setFile] = useState(null)
  const [portrait, setPortrait] = useState(null)
  const [server, setServer] = useState(serverList[0][0])
  const [exposure, setExposure] = useState(exposureList[0][0])
  const [expiration, setExpiration] = useState(expirationList[0][0])
  const [typeTags, setTypeTags] = useState([])
  const [featureTags, setFeatureTags] = useState([])
  const [purposeTags, setPurposeTags] = useState([])

  const [state, setState] = useState()
  const forceUpdate = useCallback(() => setState({}), [])
  console.log(state)

  const initialize = () => {
    setIsModalOpen(false)
    setModalOpacity(0)
    setCurrentStep(0)
    setFile(null)
    setPortrait(null)
    setServer(serverList[0][0])
    setExposure(exposureList[0][0])
    setExpiration(expirationList[0][0])
    setTypeTags([])
    setFeatureTags([])
    setPurposeTags([])
  }

  // Modal

  const toggleModal = (e) => {
    setModalOpacity(0)
    setIsModalOpen(!isModalOpen)
  }

  const afterModalOpen = () => {
    setTimeout(() => {
      setModalOpacity(1)
    }, 100)
  }

  const beforeModalClose = () => {
    return new Promise((resolve) => {
      setModalOpacity(0)
      setTimeout(resolve, 300)
    })
  }

  const cancelModal = (e) => {
    toggleModal(e)
    initialize()
  }

  // Dropzones

  const onCharacterDrop = useCallback((acceptedFiles) => {
    setFile(acceptedFiles[0])
    toggleModal()
  }, [])

  const onPortraitDrop = useCallback((acceptedFiles) => {
    setPortrait(acceptedFiles[0])
  }, [])

  const characterDropzone = useDropzone({
    onDrop: onCharacterDrop,
    accept: '.bic'
  })
  const portraitDropzone = useDropzone({
    onDrop: onPortraitDrop,
    accept: '.tga'
  })

  // Steps

  const nextStep = () => {
    setCurrentStep(currentStep + 1)
  }

  const previousStep = () => {
    setCurrentStep(currentStep - 1)
  }

  // Form

  const hasTag = (tags, name) => {
    return tags.indexOf(name) >= 0
  }

  const updateTags = (tags, name, fn) => {
    if (hasTag(tags, name)) {
      tags.splice(tags.indexOf(name), 1)
    } else {
      tags.push(name)
    }

    fn(tags)
    forceUpdate()
  }

  const onChangeServer = (e) => {
    setTypeTags([])
    setFeatureTags([])
    setPurposeTags([])
    setServer(e.target.value)
  }

  const onChangeExposure = (e) => {
    setExposure(e.target.value)
  }

  const onChangeExpiration = (e) => {
    setExpiration(e.target.value)
  }

  const hasTypeTag = (name) => {
    return hasTag(typeTags, name)
  }

  const hasFeatureTag = (name) => {
    return hasTag(featureTags, name)
  }

  const hasPurposeTag = (name) => {
    return hasTag(purposeTags, name)
  }

  const onChangeTypeTag = (e) => {
    updateTags(typeTags, e.target.name, setTypeTags)
  }

  const onChangeFeatureTag = (e) => {
    updateTags(featureTags, e.target.name, setFeatureTags)
  }

  const onChangePurposeTag = (e) => {
    updateTags(purposeTags, e.target.name, setPurposeTags)
  }

  const submit = () => {
    // form already has file and portrait elements
    const form = document.querySelector('#upload-form')
    const serverInput = document.createElement('input')
    const exposureInput = document.createElement('input')
    const expirationInput = document.createElement('input')
    const typeTagsInput = document.createElement('input')
    const featureTagsInput = document.createElement('input')
    const purposeTagsInput = document.createElement('input')

    serverInput.type = 'hidden'
    exposureInput.type = 'hidden'
    expirationInput.type = 'hidden'
    typeTagsInput.type = 'hidden'
    featureTagsInput.type = 'hidden'
    purposeTagsInput.type = 'hidden'

    serverInput.name = 'server'
    exposureInput.name = 'exposure'
    expirationInput.name = 'expiration'
    typeTagsInput.name = 'tags-type'
    featureTagsInput.name = 'tags-features'
    purposeTagsInput.name = 'tags-purpose'

    serverInput.value = server
    exposureInput.value = exposure
    expirationInput.value = expiration
    typeTagsInput.value = typeTags
    featureTagsInput.value = featureTags
    purposeTagsInput.value = purposeTags

    form.appendChild(serverInput)
    form.appendChild(exposureInput)
    form.appendChild(expirationInput)
    form.appendChild(typeTagsInput)
    form.appendChild(featureTagsInput)
    form.appendChild(purposeTagsInput)

    form.submit()
  }

  // Markup

  const exposureMarkup = []
  const expirationMarkup = []
  const serverMarkup = []
  const tagMarkup = []
  const stepMarkup = []

  const appendTags = (server, category, tagChecker, changeHandler) => {
    const tagLabels = []

    for (const tag of tagList[server][category]) {
      tagLabels.push(
        <div key={'modal-' + category + '-' + tag} className='column is-one-quarter'>
          <label className='checkbox'>
            <input type='checkbox' name={tag} checked={tagChecker(tag)} onChange={changeHandler} />
            <span className='checkbox-text'>{tag}</span>
          </label>
        </div>
      )
    }

    tagMarkup.push(
      <hr key={'modal-' + category + '-hr'} />
    )

    switch (category) {
      case 'type':
        tagMarkup.push(
          <p key={'modal-' + category + '-subheader'} className='character-modal-subheader'>
            <strong>(Optional) Build Type:</strong>
          </p>
        )
        break
      case 'features':
        tagMarkup.push(
          <p key={'modal-' + category + '-subheader'} className='character-modal-subheader'>
            <strong>(Optional) Build Features:</strong>
          </p>
        )
        break
      case 'purpose':
        tagMarkup.push(
          <p key={'modal-' + category + '-subheader'} className='character-modal-subheader'>
            <strong>(Optional) Build Purpose:</strong>
          </p>
        )
        break
    }

    tagMarkup.push(
      <div key={'modal-' + category + '-tags'} className='columns is-multiline character-modal-columns'>
        {tagLabels}
      </div>
    )
  }

  for (const option of exposureList) {
    exposureMarkup.push(
      <option key={'exposure-' + option[0]} value={option[0]}>{option[1]}</option>
    )
  }

  for (const option of expirationList) {
    expirationMarkup.push(
      <option key={'expiration-' + option[0]} value={option[0]}>{option[1]}</option>
    )
  }

  for (const option of serverList) {
    serverMarkup.push(
      <option key={'server-' + option[0]} value={option[0]}>{option[1]}</option>
    )
  }

  appendTags(server, 'type', hasTypeTag, onChangeTypeTag)
  appendTags(server, 'features', hasFeatureTag, onChangeFeatureTag)
  appendTags(server, 'purpose', hasPurposeTag, onChangePurposeTag)

  switch (currentStep) {
    case 0:
      stepMarkup.push(
        <div key='modal-step-0' id='modal-step-0'>
          <div className='modal-select-container level'>
            <div className='level-left'>
              <div className='level-item'>
                <span className='modal-select-label'>Game / Server:</span>
                <div className='select is-small character-modal-select'>
                  <select className='character-modal-select' value={server} onChange={onChangeServer}>{serverMarkup}</select>
                </div>
              </div>
              <div className='level-item'>
                <span className='modal-select-label'>Character Exposure:</span>
                <div className='select is-small character-modal-select'>
                  <select className='character-modal-select' value={exposure} onChange={onChangeExposure}>{exposureMarkup}</select>
                </div>
              </div>
              <div className='level-item'>
                <span className='modal-select-label'>Character Expiration:</span>
                <div className='select is-small character-modal-select'>
                  <select className='character-modal-select' value={expiration} onChange={onChangeExpiration}>{expirationMarkup}</select>
                </div>
              </div>
            </div>
          </div>
          {tagMarkup}
          <hr />
          <div className='modal-step-buttons level'>
            <div className='level-left'>
              <div className='level-item'>
                <button type='button' className='button is-danger' onClick={cancelModal}>Cancel</button>
              </div>
            </div>
            <div className='level-right'>
              <div className='level-item'>
                <button type='button' className='button is-info' onClick={nextStep}>Continue</button>
              </div>
            </div>
          </div>
        </div>
      )
      break
    case 1:
      stepMarkup.push(
        <div key='modal-step-1' id='modal-step-1'>
          <p><strong>Portrait (Optional)</strong></p>
          <p>If you wish to upload a portrait, you must choose a 256x512 pixel TGA file.</p>
          <div id='portrait-upload-dropzone' className='dropzone' {...portraitDropzone.getRootProps()}>
            <input name='portrait' {...portraitDropzone.getInputProps()} />
            {portraitDropzone.isDragActive
              ? <p><i className='fa-solid fa-upload' /> Drop portrait here!</p>
              : portrait
                ? <p><i className='fa-solid fa-upload' />{portrait.name}</p>
                : <p><i className='fa-solid fa-upload' />Upload portrait here!</p>}
          </div>
          <hr />
          <div className='modal-step-buttons level'>
            <div className='level-left'>
              <div className='level-item'>
                <button type='button' className='button is-info' onClick={previousStep}>Previous</button>
              </div>
            </div>
            <div className='level-right'>
              <div className='level-item'>
                <button type='button' className='button is-success' onClick={submit}>Finish</button>
              </div>
            </div>
          </div>
        </div>
      )
      break
    default: break
  }

  // Render

  return (
    <div>
      <form id='upload-form' action='/' method='post' encType='multipart/form-data'>
        <div id='character-upload-dropzone' className='dropzone' {...characterDropzone.getRootProps()}>
          <input name='file' {...characterDropzone.getInputProps()} />
          {characterDropzone.isDragActive
            ? <p><i className='fa-solid fa-upload' /> Drop character here!</p>
            : <p><i className='fa-solid fa-upload' /> Upload character here!</p>}
        </div>
        <ModalProvider backgroundComponent={CharacterUploadModalBackground}>
          <CharacterUploadModal
            className='character-upload-modal card'
            isOpen={isModalOpen}
            afterOpen={afterModalOpen}
            beforeClose={beforeModalClose}
            onBackgroundClick={cancelModal}
            onEscapeKeydown={cancelModal}
            opacity={modalOpacity}
            backgroundProps={{ modalOpacity }}
          >
            <header className='card-header'>
              <p className='card-header-title'>
                {file ? file.name : ''}
              </p>
            </header>
            <div className='card-content'>
              {stepMarkup}
            </div>
          </CharacterUploadModal>
        </ModalProvider>
      </form>
    </div>
  )
}

ReactDOM.render(React.createElement(CharacterUploadContainer), document.querySelector('#main-modal'))
